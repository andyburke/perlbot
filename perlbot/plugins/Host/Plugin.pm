# Andrew Burke <burke@pas.rochester.edu>
#
# does a host lookup, and also catches nslookups
#

package Host::Plugin;

use Perlbot;
use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg};
}

sub on_public {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^!(host|nslookup)/) {
   lookup($conn, $event, $event->{to}[0]);
  }
}  

sub on_msg {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^!(host|nslookup)/) {
    lookup($conn, $event, $event->nick);
  }
}  

sub lookup {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $in;

  if (!defined($pid = fork)) {
    $conn->privmsg($chan, "error in host plugin... weird.");
    return;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...

    ($in = $event->{args}[0]) =~ s/^!(host|nslookup)\s*//;

    $in =~ s/\`//g; #security?
    $in =~ s/\$//g;
    $in =~ s/\|//g;

    if($in eq '') {
      $conn->privmsg($who, "you must specify a host to look up...");
      $conn->{_connected} = 0;
      exit 1;
    }

    my @lookup = `host $in`;
    chomp $lookup[0];
    $conn->privmsg($who, $lookup[0]);
    $conn->{_connected} = 0;
    exit 0;
  }
}

1;
