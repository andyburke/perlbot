package Perlbot::Plugin::Logger;

use Perlbot::Utils;
use Perlbot;
use User;
use Plugin;

@ISA = qw(Plugin);

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->{perlbot}->add_handler('public', sub { $self->log(@_) }, $self->{name});
  $self->{perlbot}->add_handler('caction', sub {$self->log(@_) }, $self->{name});
  $self->{perlbot}->add_handler('join', sub {$self->log(@_) }, $self->{name});
  $self->{perlbot}->add_handler('part', sub {$self->log(@_) }, $self->{name});
  $self->{perlbot}->add_handler('mode', sub {$self->log(@_) }, $self->{name});
  $self->{perlbot}->add_handler('topic', sub {$self->log(@_) }, $self->{name});
  $self->{perlbot}->add_handler('nick', sub {$self->log(@_) }, $self->{name});
  $self->{perlbot}->add_handler('quit', sub {$self->log(@_) }, $self->{name});
  $self->{perlbot}->add_handler('kick', sub {$self->log(@_) }, $self->{name});

}

# ============================================================
# event handlers
# ============================================================

sub log {
  my $self = shift;
  my $event = shift; 
  my $type = $event->type;
  my $nick = $event->nick;

  if($type eq 'public') {
    my $channel = $event->{to}[0];
    my $text = $event->{args}[0];
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->log_write("<$nick> $text");
    }
  } elsif($type eq 'caction') {
    my $channel = $event->{to}[0];
    my $text = $event->{args}[0];
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->log_write("* $nick $text");
    }
  } elsif($type eq 'join') {
    my $channel = $event->{to}[0];
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->log_write("$nick (".$event->userhost.") joined $channel");
    }
  } elsif($type eq 'part') {
    my $channel = $event->{to}[0];
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->log_write("$nick (".$event->userhost.") left $channel");
    }
  } elsif($type eq 'mode') {
    my $channel = $event->{to}[0];
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->log_write('[MODE] ' . $event->nick . ' set mode: ' . join(' ', @{$event->{args}}));
    }
  } elsif($type eq 'topic') {
    my $channel = $event->{to}[0];
    my $text = $event->{args}[0];
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->log_write("[TOPIC] $nick: $text");
    }
  } elsif($type eq 'nick') {
    my $channel = $event->{to}[0];
    my $newnick = $event->{args}[0];
    foreach my $chan (values(%{$self->{perlbot}{channels}})) {
      if($chan->is_member($nick) || $chan->is_member($newnick)) {
        $chan->log_write("[NICK] $nick changed nick to: $newnick");
      } 
    }
  } elsif($type eq 'quit') {
    my $channel = $event->{to}[0];
    my $text = $event->{args}[0];
    foreach my $chan (values(%{$self->{perlbot}{channels}})) {
      if($chan->is_member($nick)) {
        $chan->log_write("[QUIT] $nick quit: $text");
        $chan->remove_member($nick);
      }
    }
  } elsif($type eq 'kick') {
    my $channel = $event->{args}[0];
    if($self->{perlbot}{channels}{$channel}) {
      $self->{perlbot}{channels}{$channel}->log_write('[KICK] ' . $event->{to}[0] . ' was kicked by ' . $event->nick . ' (' . $event->{args}[1] . ')');
    }
  }
}

1;
