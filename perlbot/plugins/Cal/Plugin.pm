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

  if ($event->{args}[0] =~ /^${pluginprefix}cal\s*/) {
    cal($conn, $event, $event->{to}[0]);
  }
}  

sub on_msg {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^${pluginprefix}cal\s*/) {
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

    # strip !cal command, and leading/trailing spaces
    ($in = $event->{args}[0]) =~ s/^${pluginprefix}cal\s*(.*?)\s*/$1/;

    $in =~ s/\`//g; #security?
    $in =~ s/\$//g;
    $in =~ s/\|//g;

    my @cal;
    # no options allowed.  if month is to be specified,
    # year must be specified as well.
    my ($params) = $in =~ /^(\d+\s+\d+)$/;
    if ($params !~ /-/) {
      @cal = `cal $params`;
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
