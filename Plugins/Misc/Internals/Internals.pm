# Prints contents of internal variables.  Limited to owners.
#
# Author: Mike Edwards	Date: 10/22/2001
#
# This free software is licensed under the terms of the GNU public license.
# Copyleft 2001 Mike Edwards
#
# Ported to the new plugin interface by burke@bitflood.org

package Perlbot::Plugin::Internals;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);

use Perlbot;
use Data::Dumper;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

#  $self->want_reply_via_msg(1);
#  $self->want_fork(0);

  $self->hook( trigger => 'internal', coderef => \&internal, authtype => 'admin' );
}

sub internal {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my ($var, $replymethod) = split(' ', $text);

  my @data;

  @data = split '\n', Dumper (eval sprintf "%s", $var);
  if($replymethod eq "stdout") {
    # send to console
    print STDERR "internals: $var\n";
    print join "\n", @data;
    print "\ninternals: end of $var\n";
  } else {
    # send to privmsg
    $self->reply("internals: $var");
    foreach (@data) {
      $self->reply($_);
    }
    $self->reply("internals: end of $var");
  }
}

1;
