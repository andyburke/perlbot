package Perlbot::Plugin::Hook::Public;

use strict;
use Perlbot::Plugin::Hook;
use base qw(Perlbot::Plugin::Hook);

sub new {
  my $class = shift;
  my $self = fields::new($class);

  $self->SUPER::new(@_);

}

sub process {
  my $self = shift;
  my $event = shift;
  my $user = shift;
  my $text = shift;

  return if($event->type ne 'public');
  
  print "public event processed...\n";
}
