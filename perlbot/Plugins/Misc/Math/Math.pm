package Perlbot::Plugin::Math;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use Perlbot;
use Safe;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->hook('math', \&math);
}

sub math {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $compartment = new Safe();
  $compartment->permit_only(qw(:base_core));

  my $result = $compartment->reval($text);
  if(length($result) > 0) {
    $self->reply($result);
  } else {
    $self->reply("Enter a valid perl mathematical expression!");
  }
}

1;
