# Cal
# Jeremy Muhlich
#
# calls the unix util 'cal' to print out a calendar

package Cal::Plugin;

use Perlbot;
use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg};
}

sub on_public {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^!cal\s*/) {
    cal($conn, $event, $event->{to}[0]);
  }
}  

sub on_msg {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^!cal\s*/) {
    cal($conn, $event, $event->nick);
  }
}  

sub cal {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $in;

  if (!defined($pid = fork)) {
    $conn->privmsg($chan, "error in cal...");
    return;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...

    ($in = $event->{args}[0]) =~ s/^!cal\s*//;

    $in =~ s/\`//g; #security?
    $in =~ s/\$//g;
    $in =~ s/\|//g;

    my @cal;
    # -y gives a calendar for the whole year.. TOO BIG :)
    if ($in =~ /-\w*y/) {
      @cal = ("-y eh?  What are you trying to pull here?");
    } else {
      @cal = `cal $in`;
    }

    chomp @cal;
    foreach(@cal) {
      $conn->privmsg($who, $_);
    }
    
    $conn->{_connected} = 0;
    exit 0;			# kill child
  }
}

1;
