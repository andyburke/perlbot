package Perlbot::PluginConfig;


# This package subclasses Perlbot::Config, and simply overrides _value
# to provide a Plugin object "rooted" at a given plugin's tree in the
# config.

use strict;
use base qw(Perlbot::Config);
use fields qw(plugin_name);


sub new {
  my $class = shift;
  my ($plugin_name, $filename, $readonly) = (@_);

  my $self = fields::new($class);
  $self->{plugin_name} = $plugin_name;
  $self->SUPER::new($filename, $readonly);

  return $self;
}


# Here we insert 'plugin',<plugin_name> at the front of the key list.
# This affects all of get, set, array_*, hash_*, etc. on this object!
sub _value : lvalue {
  my ($self, @keys) = @_;
  $self->SUPER::_value(plugin => $self->{plugin_name} => @keys);
}



1;

