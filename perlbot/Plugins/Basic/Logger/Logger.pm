package Perlbot::Plugin::Logger;

use strict;
use base qw(Perlbot::Plugin);
use Perlbot;
use Perlbot::Logs::Event;
use Perlbot::Utils;
use Perlbot::User;

our $VERSION = '1.0.0';

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
  my $channel;
  # stupid, stupid irc
  $event->type eq 'kick' ? $channel = $event->{args}[0] : $channel = $event->{to}[0];

  # nick changes and quits are not associated with channels,
  # so we need to brutal force it
  if($event->type eq 'nick') {
    my $newnick = $event->{args}[0];
    foreach my $chan (values(%{$self->perlbot->channels})) {
      if ($chan->is_member($event->nick) || $chan->is_member($newnick)) {
        $chan->log_event($event);
      } 
    } 
  } elsif($event->type eq 'quit') {
    foreach my $chan (values(%{$self->perlbot->channels})) {
      if ($chan->is_member($event->nick)) {
        $chan->log_event($event);
        $chan->remove_member($event->nick); # unr, so dirty (note: race w/ UserUpdater)
      }
    }
  } else { # otherwise, just log it, so do it
    my $chan = $self->perlbot->get_channel($channel);
    $chan->log_event($event) if $chan;
  }
}

1;




