package Perlbot::Plugin::UserUpdater;

use Perlbot::Utils;
use Perlbot;
use Perlbot::User;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

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

  my $userhost = $event->nick.'!'.$event->userhost;
  my $type = $event->type;
  my $nick = $event->nick;
  my $channel = normalize_channel($event->{to}[0]);
  my $text = $event->{args}[0];
  my $user = $self->{perlbot}->get_user($userhost);

  if($type eq 'join') {
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->add_member($nick);
    }
  }

  if($type eq 'part') {
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->remove_member($nick);
    }
  }

  if($type eq 'quit') {
    $self->{lastquit} = $nick;
  }

  if($type eq 'nick') {
    foreach my $chan (values(%{$self->{perlbot}{channels}})) {
      if($chan->is_member($nick)) {
        $chan->remove_member($nick);
        $chan->add_member($event->{args}[0]);
      }
    }
  }

  if($type eq 'kick') {
    my $chan = normalize_channel($event->{args}[0]);
    if($self->{perlbot}{channels}{$chan}) {
      $self->{perlbot}{channels}{$chan}->remove_member($nick);
    }
  }

  if($type eq 'namreply') {
    my $chan = normalize_channel($event->{args}[2]);
    my $nickstring = $event->{args}[3];
    $nickstring =~ s/\@//g;
    my @nicks = split(' ', $nickstring);
    if($self->{perlbot}{channels}{$chan}) {
      foreach my $nick (@nicks) {
        $self->{perlbot}{channels}{$chan}->add_member($nick);
      }
    }
  }

  if($self->{lastquit}) {
    foreach my $channel (keys(%{$self->{perlbot}{channels}})) {
      $self->{perlbot}{channels}{$channel}->remove_member($nick);
    }
  }

  if($user) {
    $user->{curnick} = $nick;
    $user->{lastseen} = time();

    if(!$user->{notified} && $user->notes >= 1) {
      my $numnotes = $user->notes;
      my $noteword = ($numnotes == 1) ? 'note' : 'notes';
      $self->{perlbot}->msg($nick, "$numnotes $noteword stored for you.");
      $user->{notified} = 1;
    }
  }
  return $user;

}

1;

