# Andrew Burke <burke@pas.rochester.edu>
#
# does a traceroute...
#
# ported/mangled from:
# infobot :: Kevin Lenzo & Patrick Cole   (c) 1997

package Traceroute::Plugin;

use Perlbot;
use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg};
}

sub on_public {
  my $conn = shift;
  my $event = shift;

  if (($event->{args}[0] =~ /^!traceroute\s*/) || ($event->{args}[0] =~ /^!tr\s*/)) {
    troute($conn, $event, $event->{to}[0]);
  }
}  

sub on_msg {
  my $conn = shift;
  my $event = shift;

  if (($event->{args}[0] =~ /^!traceroute\s*/)  || ($event->{args}[0] =~ /^!tr\s*/)) {
    troute($conn, $event, $event->nick);
  }
}  

sub troute {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $in;

  if (!defined($pid = fork)) {
    $conn->privmsg($chan, "error in traceroute... weird.");
    return;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...

    ($in = $event->{args}[0]) =~ s/^!traceroute\s*//;

    $in =~ s/\`//g; #security?
    $in =~ s/\$//g;
    $in =~ s/\|//g;
    
    my @tr = `traceroute $in`;
    chomp @tr;

    foreach(@tr) {
      $conn->privmsg($who, $_);
    }
    
    $conn->{_connected} = 0;
    exit 0;			# kill child
  }
}

1;
