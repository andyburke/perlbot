package Perlbot::Plugin::Hook;

use strict;
use vars qw($AUTOLOAD %FIELDS);
use fields qw(value code flags type);

sub new {
  my $class = shift;
  my $value = shift;
  my $code = shift;
  my $flags = shift;

  my $self = fields new($class);

  $self->value = $value;
  $self->code = $code;
  $self->flags = $flags;
  $self->type = undef;

  return $self;
}

sub process {
  my $self = shift;

  die(ref($self) . "::process not implemented!");
}

1;
