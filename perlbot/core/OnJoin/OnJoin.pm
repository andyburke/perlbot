package Perlbot::Plugin::OnJoin;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;

  $self->want_fork(0);
  $self->want_public(0);
  $self->want_msg(0);

  $self->hook_event('join', \&onjoin);
}

sub onjoin {
  my $self = shift;
  my $event = shift;

  my $user = $self->{perlbot}->get_user($event->from());

  if($user && $self->{perlbot}{channels}{Perlbot::Utils::normalize_channel($event->{to}[0])}{ops}{$user->{name}}) {
    $self->{perlbot}->op($event->{to}[0], $event->nick());
  }
}

1;
