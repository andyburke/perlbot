# Andrew Burke <burke@pas.rochester.edu>
#
# dictionary

package Dictionary::Plugin;

use strict;

use Perlbot;

use LWP::Simple;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my ($conn, $event) = @_;
  my $args;

  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if ($args =~ /^${pluginprefix}dict/  || $args =~ /^${pluginchar}dictionary/) {
    get_def($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my ($conn, $event) = @_;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if ($args =~ /^${pluginprefix}dict/  || $args =~ /^${pluginchar}dictionary/) {
    get_def($conn, $event, $event->nick);
  }
}

sub get_def {
  my ($conn, $event, $chan) = @_;
  my ($pid);

  if (!defined($pid = fork)) {
    $conn->privmsg($chan, "error in dictionary plugin...");
    return;
  }

  if ($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my $args;
    ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
    $args =~ s/^${pluginprefix}dict\s*//;
    $args =~ s/^${pluginprefix}dictionary\s*//;
    $args =~ tr/[A-Z]/[a-z]/;

    my $url = "http://www.ibiblio.org/webster/cgi-bin/headword_search.pl?query=${args}&=Submit";

    my $html = get($url);
    if (!$html) {
      $conn->privmsg($chan, "Could not connect to Dictionary server.");
      $conn->{_connected} = 0;
      exit 1;
    }
    
    chomp $html;
    $html =~ s/\n//g;
    $html =~ s/&reg\;//g;
    $html =~ s/&amp\;/&/g;

    if($html =~ /0 matches/) {
      $conn->privmsg($chan, "No such word found: $args");
      $conn->{_connected} = 0;
      exit 0;
    }

    my @tempwords;
    my %tmpwordshash;
    my @words;
    my $pos;
    my $ety;
    my @defs;

    @tempwords = $html =~ /<b><u>(.*?)<\/u><\/b>/ig;
    undef %tmpwordshash;
    @tmpwordshash{@tempwords} = ();
    @words = keys(%tmpwordshash);

    ($pos) = $html =~ /<i>(.*?)<\/i>/i;
    $pos =~ s/<.*?>//g;

    ($ety) = $html =~ /<ety>(.*?)<\/ety>/i;
    $ety =~ s/<.*?>//g;

    @defs = $html =~ /<def>(.*?)<\/def>/ig;

    $conn->privmsg($chan, "Word(s): " . join(', ', @words));
    $conn->privmsg($chan, "Part of Speech: $pos");
    $conn->privmsg($chan, "Etymology: $ety");
    my $i = 1;
    foreach my $def (@defs) {
      $def =~ s/<.*?>//g;
      $conn->privmsg($chan, "  $i: $def");
      $i++;
    }

    $conn->{_connected} = 0;
    exit 0;
  }
}

1;

