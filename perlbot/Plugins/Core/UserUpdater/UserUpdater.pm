package Perlbot::Plugin::UserUpdater;

use Perlbot::Utils;
use Perlbot;
use Perlbot::User;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

our $VERSION;

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->hook_event('public', \&update);
  $self->hook_event('caction', \&update);
  $self->hook_event('join', \&update);
  $self->hook_event('part', \&update);
  $self->hook_event('mode', \&update);
  $self->hook_event('topic', \&update);
  $self->hook_event('nick', \&update);
  $self->hook_event('quit', \&update);
  $self->hook_event('kick', \&update);
  $self->hook_event('namreply', \&update);

}

# ============================================================
# event handlers
# ============================================================

sub update {
  my $self = shift;
  my $event = shift;

  my $userhost = $event->from;
  my $type = $event->type;
  my $nick = $event->nick;
  my $channel = normalize_channel($event->{to}[0]);
  my $chan = $self->perlbot->get_channel($channel);
  my $text = $event->{args}[0];
  my $user = $self->perlbot->get_user($userhost);

  if ($type eq 'join' and $chan) {
    $chan->add_member($nick);
  }

  if ($type eq 'part' and $chan) {
    $chan->remove_member($nick);
  }

  if ($type eq 'quit') {
    # FIXME: consider a solution like plugins being able to defer
    # here we delay removing them from the channel member list so that the logger
    # can log their quit.
    $self->perlbot->ircconn->schedule(1, sub { $self->delayed_quit_remove($nick); });
  }

  if ($type eq 'nick') {
    foreach my $chan (values(%{$self->perlbot->channels})) {
      if($chan->is_member($nick)) {
        $chan->remove_member($nick);
        $chan->add_member($event->{args}[0]);
      }
    }
  }

  if ($type eq 'kick') {
    my $chan = $self->perlbot->get_channel($event->{args}[0]);
    if ($chan) {
      $chan->remove_member($nick);
    }
  }

  if ($type eq 'namreply') {
    my $chan = $self->perlbot->get_channel($event->{args}[2]);
    my $nickstring = $event->{args}[3];
    $nickstring =~ s/\@//g;
    my @nicks = split(' ', $nickstring);
    if ($chan) {
      foreach my $nick (@nicks) {
        $chan->add_member($nick);
      }
    }
  }

  if ($user) {
    $user->curnick($nick);
  }

  return $user;

}

sub delayed_quit_remove {
  my $self = shift;
  my $nick = shift;

  foreach my $channel (values(%{$self->perlbot->channels})) {
    $channel->remove_member($nick);
  }
}

1;








