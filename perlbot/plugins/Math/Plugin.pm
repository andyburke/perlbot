# Andrew Burke <burke@bitflood.org>
#
# This plugin does math using bc.  Prolly needs to be on
# a unix system...
#
# originally ported/mangled from:
# infobot copyright (C) kevin lenzo 1997-98

package Math::Plugin;

use Perlbot;
use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my $conn = shift;
  my $event = shift;
  my $who = $event->{to}[0];

  if ($event->{args}[0] =~ /^${pluginprefix}math/) {
    math($conn, $event, $who);
  }

}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $who = $event->nick;

  if($event->{args}[0] =~ /^${pluginprefix}math/) {
    math($conn, $event, $who);
  }
}

sub math {
    # Math handling.
  my $conn = shift;
  my $event = shift;
  my $who = shift;

  if (!defined($pid = fork)) {
    $conn->privmsg($who, "error in bc, or something...");
    $conn->{_connected} = 0;
    exit 1;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...
    
    my $args;
    ($args = $event->{args}[0]) =~ s/^${pluginprefix}math\s*//;
    
    $args =~ s/\s*//g;     #eat whitespace
    
    $args =~ s/arctan/a/g; #arctan->a
    $args =~ s/cos/c/g;    #cos->c (the bc function)
    $args =~ s/tan/t/g;    #tan->t
    $args =~ s/sin/s/g;    #sin->s
    $args =~ s/log/l/g;    #log->l

    $args =~ s/\`//g;  #security... ?
    $args =~ s/\$//g;
    $args =~ s/\|//g;
    
    my @bc = `echo "$args"|bc -l 2>&1`;
    foreach $line (@bc) {
      chomp $line;
      $conn->privmsg($who, $line);
    }

    $conn->{_connected} = 0;

    exit 0;

  }
}

1;
