# Prints contents of internal variables.  Limited to owners.
#
# Author: Mike Edwards	Date: 10/22/2001
#
# This free software is licensed under the terms of the GNU public license.
# Copyleft 2001 Mike Edwards

package Internals::Plugin;

use Perlbot;
use Data::Dumper;

sub get_hooks {
  return { msg => \&on_msg };
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my @args;
  my @data;

  @args = split ' ', $event->{args}[0];
  my $userhost = $event->nick . '!' . $event->userhost;
  my $user = Perlbot::host_to_user($userhost);

  if ($args[0] eq "${pluginprefix}internal") {
    ($var, $location) = @args[1,2];
    if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
      @data = split '\n', Dumper (eval sprintf "%s", $var);
      if ($location eq "msg") {
        # send to privmsg
        $conn->privmsg($event->nick, "internals: $var");
        foreach (@data) {
          $conn->privmsg($event->nick, $_);
        }
        $conn->privmsg($event->nick, "internals: end of $var");
      } else {
        # send to console
        print STDERR "internals: $var\n";
        print join "\n", @data;
        print "\ninternals: end of $var\n";
      }
    } else {
      $conn->privmsg($event->nick, "You are not a bot owner");
    }
  }
}

1;
