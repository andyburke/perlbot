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
    my ($query) = $parms;
    my $lines = '';

    if($query =~ /\d+$/) {
      $lines = $query;
      $lines =~ s/.*?(\d+)$/$1/;
    }
    $query =~ s/\d+$//;

    if($lines eq '') { $lines = 10; }
    
    die "Can't fork: $!" unless defined($pid = open(KID, "-|"));

    # Safer way of running perldoc
    #
    # Thanks to: Mike Edwards <pf-perlbot@mirkwood.net> 

    if ($pid) {
       # parent
       @text = <KID>;
       close KID;
    } else {
       # kid
       # Send stderr to stdout, so the bot will report errors back to the user
       open (STDERR, ">&STDOUT") or die "Can't dup stdout: $!\n";
       exec 'perldoc', '-t', split(' ', $query) or die "Can't exec perldoc: $!\n";
    }

    chomp @text;

    my $i = 0;
    foreach (@text) {
      $conn->privmsg($who, $_);
      if($i > $lines) { last; };
      $i++;
    }
    
    $conn->{_connected} = 0;
    exit 0;
  }
}

1;



