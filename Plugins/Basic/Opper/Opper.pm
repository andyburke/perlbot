package Perlbot::Plugin::Opper;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

#  $self->want_fork(0);
#  $self->want_public(0);
#  $self->want_msg(0);

  $self->hook( eventtypes => 'join', coderef => \&opper );
}

sub opper {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;

  my $chan = $self->perlbot->get_channel($event->{to}[0]);
  if ($chan->is_op($user)) {
    $self->perlbot->op($event->{to}[0], $event->nick);
  }
}


1;
