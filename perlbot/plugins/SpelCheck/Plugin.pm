# SpelCheck
# =========
#
# Jeremy Muhlich <jmuhlich@jhu.edu>
#
# This plugin does spell-checking using ispell.  Prolly needs to be on
# a unix system...
#
# based on:
# infobot copyright (C) kevin lenzo 1997-98

package SpelCheck::Plugin;

use Perlbot;
use POSIX;
use strict;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my $conn = shift;
  my $event = shift;
  my $who = $event->{to}[0];

  if ($event->{args}[0] =~ /^${pluginchar}spell /) {
    spell($conn, $event, $who);
  }

}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $who = $event->nick;

  if($event->{args}[0] =~ /^${pluginchar}spell /) {
    spell($conn, $event, $who);
  }
}

sub spell {
    # call ispell and parse the return
    my $conn = shift;
    my $event = shift;
    my $who = shift;
    my $pid;
    
    if (!defined($pid = fork)) {
	$conn->privmsg($who, "ispell crapped out on me.  sorry.");
	$conn->{_connected} = 0;
	exit 1;
    }

    if ($pid) {
	# parent
	$SIG{CHLD} = sub { wait; };
	return;
    } else {
	# child
	my $args;
	($args = $event->{args}[0]) =~ s/^${pluginchar}spell\s*//;
    
	# kill all punctuation that might piss off ispell, or the shell (?)
	$args =~ tr/\w //c;

	$args =~ s/\`//g;
	$args =~ s/\$//g;
	$args =~ s/\|//g;

	# -S means sort by probability of correctness
	# -a means take input from stdin
	my @spell = `echo "$args"| ispell -S -a 2>&1`;
	my $ok = 1;
	chomp(@spell);
	foreach my $line (@spell) {
	    my ($code, $word, $suggest, $response);
	    ($code, $word, undef, undef, $suggest) = split(' ', $line, 5);
	    # The code tells us how the dictionary lookup went:
	    # * -> the spelling was OK
	    # + -> the word was found via affix removal (i.e. it's OK)
	    # - -> the word was found; it's a compund (i.e. it's OK)
	    # & -> the word wasn't found, but ispell has some near misses and guesses
	    # ? -> the word wasn't found, but ispell has some guesses
	    # # -> the word wasn't found, and ispell has no idea what you're talking about
	    # NOTE: We ignore the guesses, so only print the near misses from &,
	    #       and treat ? like #.  Also, we don't pass -C, so code - should
	    #       never come up.  But OK spellings are just ignored, so it
	    #       will work ok if somehow -C does get passed.
	    if ($code eq '&') {
		$response = "$word: $suggest";
		$ok = 0;
	    } elsif ($code eq '#' or $code eq '?') {
		$response = "$word... stop talking nonsense";
		$ok = 0;
	    }
	    $conn->privmsg($who, $response);
	}
	$conn->privmsg($who, "All words checked out OK") if $ok;

	$conn->{_connected} = 0;

	exit 0;

    }
}

1;
