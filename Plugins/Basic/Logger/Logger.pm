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

#  $self->want_fork(0);

  $self->hook( eventtypes => 'public', coderef => \&log );
  $self->hook( eventtypes => 'caction', coderef => \&log );
  $self->hook( eventtypes => 'join', coderef => \&log );
  $self->hook( eventtypes => 'part', coderef => \&log );
  $self->hook( eventtypes => 'mode', coderef => \&log );
  $self->hook( eventtypes => 'topic', coderef => \&log );
  $self->hook( eventtypes => 'nick', coderef => \&log );
  $self->hook( eventtypes => 'quit', coderef => \&log );
  $self->hook( eventtypes => 'kick', coderef => \&log );

}

# ============================================================
# event handlers
# ============================================================

sub log {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift; 
  my $channel;
  # stupid, stupid irc
  $channel = $event->type eq 'kick' ? $event->{args}[0] : $event->{to}[0];

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




