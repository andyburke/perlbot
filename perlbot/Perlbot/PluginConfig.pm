package Perlbot::PluginConfig;


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

sub _value : lvalue {
  my ($self, @keys) = @_;
  $self->SUPER::_value(plugin => $self->{plugin_name} => @keys);
}



1;

