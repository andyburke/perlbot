package Perlbot::Plugin::Opper;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;

  $self->want_fork(0);
  $self->want_public(0);
  $self->want_msg(0);

  $self->hook_event('join', \&opper);
}

sub opper {
  my $self = shift;
  my $event = shift;

  my $user = $self->{perlbot}->get_user($event->from());
  my $chan = $self->{perlbot}->get_channel($event->{to}[0]);

  if($user && (grep {$_ eq $user->name } @{$chan->ops})) {
    $self->{perlbot}->op($event->{to}[0], $event->nick());
  }
}

1;
