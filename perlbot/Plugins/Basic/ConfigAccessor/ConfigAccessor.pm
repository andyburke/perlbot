package Perlbot::Plugin::ConfigAccessor;

use strict;
use base qw(Perlbot::Plugin);
use Perlbot;

our $VERSION = '0.0.1';

sub init {
  my $self = shift;

#  $self->want_public(0);
#  $self->want_fork(0);

  $self->hook_admin('config', \&configaccessor);
}

sub configaccessor {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($action, $args) = split(/ /, $text, 2);
  
  debug("action: $action / args: $args", 5);

  if(lc($action) eq 'get') {
    debug("Getting config value: $args", 4);
    $self->reply($self->perlbot->config->get(eval "$args"));
  } elsif(lc($action) eq 'set') {
    my ($key, $value) = split(/,/, $args, 2);
    debug("Setting config value: $key to value: $value", 4);
    $self->reply($self->perlbot->config->set(eval "$key", $value));
  } else {
    $self->reply_error("Unknown config command: $action!");
  }
}

1;
