package Perlbot::Plugin::Logger;

use Perlbot;
use Perlbot::Utils;
use Perlbot::User;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->hook_event('public', \&log);
  $self->hook_event('caction', \&log);
  $self->hook_event('join', \&log);
  $self->hook_event('part', \&log);
  $self->hook_event('mode', \&log);
  $self->hook_event('topic', \&log);
  $self->hook_event('nick', \&log);
  $self->hook_event('quit', \&log);
  $self->hook_event('kick', \&log);


}

# ============================================================
# event handlers
# ============================================================

sub log {
  my $self = shift;
  my $event = shift; 
  my $type = $event->type;
  my $nick = $event->nick;

  my $channel = $event->{to}[0];
  my $chan = $self->perlbot->get_channel($channel);

  if($type eq 'public') {
    my $text = $event->{args}[0];
    if ($chan) {
      $chan->log_write("<$nick> $text");
    }
  } elsif($type eq 'caction') {
    my $text = $event->{args}[0];
    if ($chan) {
      $chan->log_write("* $nick $text");
    }
  } elsif($type eq 'join') {
    if ($chan) {
      $chan->log_write("$nick (".$event->userhost.") joined $channel");
    }
  } elsif($type eq 'part') {
    if ($chan) {
      $chan->log_write("$nick (".$event->userhost.") left $channel");
    }
  } elsif($type eq 'mode') {
    if ($chan) {
      $chan->log_write('[MODE] ' . $event->nick . ' set mode: ' . join(' ', @{$event->{args}}));
    }
  } elsif($type eq 'topic') {
    my $text = $event->{args}[0];
    if ($chan) {
      $chan->log_write("[TOPIC] $nick: $text");
    }
  } elsif($type eq 'nick') {
    my $newnick = $event->{args}[0];
    foreach my $chan (values(%{$self->perlbot->channels})) {
      if ($chan->is_member($nick) || $chan->is_member($newnick)) {
        $chan->log_write("[NICK] $nick changed nick to: $newnick");
      } 
    }
  } elsif($type eq 'quit') {
    my $text = $event->{args}[0];
    foreach my $chan (values(%{$self->perlbot->channels})) {
      if ($chan->is_member($nick)) {
        $chan->log_write("[QUIT] $nick quit: $text");
        $chan->remove_member($nick);
      }
    }
  } elsif($type eq 'kick') {
    my $chan = $self->perlbot->get_channel($event->{args}[0]);
    if ($chan) {
      $chan->log_write('[KICK] ' . $event->{to}[0] . ' was kicked by ' . $event->nick . ' (' . $event->{args}[1] . ')');
    }
  }
}

1;
