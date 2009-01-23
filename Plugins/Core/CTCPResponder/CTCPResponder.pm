package Perlbot::Plugin::CTCPResponder;

use strict;
use base qw(Perlbot::Plugin);
use Perlbot;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;
  
#  $self->want_fork(0);
#  $self->want_public(0);
#  $self->want_msg(0);
  
  $self->hook( eventtypes => 'cping', coderef => \&cping );
  $self->hook( eventtypes => 'cversion', coderef => \&cversion );
}

sub cping {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;

  $self->perlbot->ircconn->ctcp_reply($event->nick, join (' ', ('PING', $event->args)));
}

sub cversion {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;
  
  $self->perlbot->ircconn->ctcp_reply($event->nick,
                                      "VERSION Perlbot version: $Perlbot::VERSION / by: $Perlbot::AUTHORS");
}

1;
