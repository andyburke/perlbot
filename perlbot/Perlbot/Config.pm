package Perlbot::Config;


use strict;
use XML::Simple;
use Perlbot::Utils;


sub new {
  my $class = shift;
  my ($filename) = (@_);

  my $self = {
    _filename => $filename,
    _config => {},
  };

  bless $self, $class;

  $self->load;

  return $self;
}


sub load {
  my ($self) = @_;

  $self->{_config} = read_generic_config($self->{_filename});
}


sub save {
  my ($self) = @_;

  write_generic_config($self->{_filename}, $self->{_config});
}


sub get {
  my ($self, $class, $key, $field) = @_;
  my $ref;

  $ref = $self->{_config};
  if (!defined $class) {
    # return entire config
    return $ref;
  }

  $ref = $ref->{$class};
  if (!defined $key) {
    # return array or hashref of all objects in a given class
    if (ref($ref) eq 'ARRAY') {
      return @{$ref};
    } else {
      return $ref;
    }
  }

  if (ref($ref) eq 'ARRAY') {
    if (@{$ref} == 1 and $key =~ /\D/) {
      $field = $key;
      $key = 0;
    }
    $ref = $ref->[$key];
  } else {
    $ref = $ref->{$key};
  }
  if (!defined $field) {
    # return a given object in a given class
    return $ref;
  }

  # return array of all fields in a given object in a given class,
  # or a single value if there is only one
  $ref = $ref->{$field};
  if (ref($ref) eq 'ARRAY') {
    if (@{$ref} == 1) {
      return $ref->[0];
    } else {
      return @{$ref};
    }
  } else {
    return $ref;
  }
}


sub set {
  my ($self) = @_;
}



1;
