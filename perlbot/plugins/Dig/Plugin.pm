# Andrew Burke <burke@bitflood.org>
#
# does a dig 
#

package Dig::Plugin;

use Perlbot;
use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg};
}

sub on_public {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^${pluginprefix}dig/) {
   dig($conn, $event, $event->{to}[0]);
  }
}  

sub on_msg {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^${pluginprefix}dig/) {
    dig($conn, $event, $event->nick);
  }
}  

sub dig {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $in;
  my @text;

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
    $in = $event->{args}[0];
    $in =~ s/^.*?\s+//;

    $in =~ s/\`//g; #security?
    $in =~ s/\$//g;
    $in =~ s/\|//g;

    if($in eq '') {
      $conn->privmsg($who, "you must specify a host to dig up...");
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
       exec 'dig', split(' ', $in) or die "Can't exec dig: $!\n";
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
