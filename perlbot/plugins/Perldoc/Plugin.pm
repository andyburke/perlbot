# Andrew Burke <burke@pas.rochester.edu>
#
# This looks up a perl function...

package Perldoc::Plugin;

use Perlbot;
use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^!perldoc/) {
    perldoc_response($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;

  if($event->{args}[0] =~ /^!perldoc/) {
    perldoc_response($conn, $event, $event->nick);
  }
}

sub perldoc_response {
  my $conn = shift;
  my $event = shift;
  my $who = shift;

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in forking perldoc...");
    return;
  }

  if ($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    #child

    ($parms = $event->{args}[0]) =~ s/^!perldoc\s*//;
    my ($func, $lines, $to) = split(' ', $parms);

    $func =~ s/\`//g; #security?
    $func =~ s/\$//g;
    $func =~ s/\|//g;
    
    if($lines eq '') { $lines = 10; }
    
    my @text = `perldoc -tf $func`;
    chomp @text;

    my $i = 0;
    if($to) {
      foreach (@text)  {
	$conn->privmsg($to, $_);
	if($i > $lines) { last; };
	$i++;
      }
    } else {
      foreach (@text) {
	$conn->privmsg($who, $_);
	if($i > $lines) { last; };
	$i++;
      }
    }
    
    $conn->{_connected} = 0;
    exit 0;
  }
}

1;



