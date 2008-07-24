package Perlbot::Logs;

use Perlbot;
use Perlbot::Utils;
use strict;

use File::Spec;
use Time::Local;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(perlbot channel config index);

sub new {
  my ($class, $perlbot, $channel, $config, $index) = @_;

  my $self = fields::new($class);

  $self->perlbot = $perlbot;
  $self->channel = $channel;
  $self->config = $config;
  $self->index = $index;

  return $self;
}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  if(!exists($FIELDS{$field})) {
    die "AUTOLOAD: no such method/field '$field'";
  }

  debug("Got call for field: $field", 15);

  $self->{$field};
}

sub config_get {
  my $self = shift;
  my $field = shift;

  return $self->config->get(channel => $self->channel => log => $self->index => $field);
}

sub config_set {
  my $self = shift;
  my $field = shift;
  my $value = shift;

  return $self->config->set(channel => $self->channel => log => $self->index => $field, $value);
}

# dummy subs, meant to be overridden

sub log_event {
  my $self = shift;
  die(ref($self) . "::log_event not implemented!");
}

sub search {
  my $self = shift;
  die(ref($self) . "::search not implemented!");
}

sub initial_entry_time {
  my $self = shift;
  die(ref($self) . "::initial_entry_time not implemented!");
}

sub final_entry_time {
  my $self = shift;
  die(ref($self) . "::final_entry_time not implemented!");
}

sub DESTROY {
  # dummy
}


1;
