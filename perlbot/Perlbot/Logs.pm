package Perlbot::Logs;

use Perlbot;
use Perlbot::Utils;
use strict;

use File::Spec;
use Time::Local;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(perlbot);

sub new {
  my ($class, $perlbot) = @_;

  my $self = fields::new($class);

  $self->perlbot = $perlbot;

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

# dummy subs, meant to be overridden

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
