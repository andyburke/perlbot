# Andrew Burke <burke@pas.rochester.edu>
#
# does a traceroute

package Traceroute::Plugin;

use Perlbot;
use POSIX;

my $traceroutebinary = '/usr/sbin/traceroute';

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg};
}

sub on_public {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^${pluginprefix}(traceroute|tr)/) {
   trace($conn, $event, $event->{to}[0]);
  }
}  

sub on_msg {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^${pluginprefix}(traceroute|tr)/) {
    trace($conn, $event, $event->nick);
  }
}  

sub trace {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $in;
  my @text;

  if (!defined($pid = fork)) {
    $conn->privmsg($chan, "error in traceroute plugin... weird.");
    return;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...

    ($in = $event->{args}[0]) =~ s/^${pluginprefix}(traceroute|tr)\s*//;

    $in =~ s/\`//g; #security?
    $in =~ s/\$//g;
    $in =~ s/\|//g;

    if($in eq '') {
      $conn->privmsg($who, "you must specify a host to trace...");
      $conn->{_connected} = 0;
      exit 1;
    }

    die "Can't fork: $!" unless defined($pid = open(KID, "-|"));

    if ($pid) {
       # parent
       @text = <KID>;
       close KID;
    } else {
       # kid
       # Send stderr to stdout, so the bot will report errors back to the user
       open (STDERR, ">&STDOUT") or die "Can't dup stdout: $!\n";
       exec $traceroutebinary, split(' ', $in) or die "Can't exec traceroute: $!\n";
    }

    chomp @text;
    foreach my $text (@text) {
      $conn->privmsg($who, $text);
    }
    $conn->{_connected} = 0;
    exit 0;
  }
}

1;
