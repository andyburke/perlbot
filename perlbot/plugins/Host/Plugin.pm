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
    foreach (@lookup) {
      chomp;
      if (/has address/) {
        $conn->privmsg($who, $_);
        $conn->{_connected} = 0;
        exit 0;
      }
    }

    # if no results, we fall through to here
    $conn->privmsg($who, "$in not found: has no DNS entry");
    $conn->{_connected} = 0;
    exit 0;			# kill child
  }
}

1;
