package Perlbot::Plugin::AdminControl;

use Perlbot;
use Perlbot::Utils;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_fork(0);

  $self->hook_admin('reload', \&reload);
}

sub nick {
  my $self = shift;
  my $user = shift;

  $self->perlbot->reload_config();
}

1;
