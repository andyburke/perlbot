package Perlbot::Plugin::ConnectionManagement;

use strict;
use base qw(Perlbot::Plugin);
use Perlbot::Utils;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->hook_event('endofmotd', \&join_channels);
  $self->hook_event('nomotd', \&join_channels);

  $self->hook_event('disconnect', \&reconnect);

  $self->hook_event('nicknameinuse', \&cycle_nick);
  $self->hook_event('nickcollision', \&cycle_nick);

}

# ============================================================
# event handlers
# ============================================================

sub join_channels {
  my $self = shift;
  my $event = shift;

  debug("Joining Channels");

  foreach my $channel (values(%{$self->perlbot->channels})) {
    debug("  Joining Channel: " . $channel->name);
    $self->perlbot->join($channel);
    debug("    Sending whois to channel: " . $channel->name, 2);
    $self->perlbot->whois($channel);
    sleep(1); # so we don't flood
  }

}

sub reconnect {
  my $self = shift;
  my $event = shift;
  my $old_server = $event->{from};
  my $server;
  my $i = 0;

  if ($$ == 0) {    # exit if we're a child...
    exit;
  }

  debug("Disconnected from: $old_server");
  debug($event->dump());
  debug("---End dump...");

  while ($i < $self->perlbot->config->array_get('server')
         && $self->perlbot->config->get(server => $i => 'address') ne $old_server) {
    debug("looking at server: " . $self->perlbot->config->get(server => $i => 'address'));
    $i++;
  }

  $i++; #look at the server AFTER the old one

  while (!$self->perlbot->connect($i)) {
    $i++;
    $i = $i % $self->perlbot->config->array_get('server');
  }
}

sub cycle_nick {
  my $self = shift;
  my $event = shift;

  my $nickappend = $self->perlbot->config->get(bot => 'nickappend');
  $nickappend ||= '_';

  $self->perlbot->nick($self->perlbot->curnick . $nickappend);
}

1;





