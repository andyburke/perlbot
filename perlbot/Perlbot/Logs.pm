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
    return;
  }

  debug("Got call for field: $field", 15);

  $self->{$field};
}

sub search {
  # dummy sub, meant to be overridden
}

1;
