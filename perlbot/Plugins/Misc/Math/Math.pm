# Andrew Burke <burke@pas.rochester.edu>
#
# This plugin does math using bc.  Prolly needs to be on
# a unix system...
#
# originally ported/mangled from:
# infobot copyright (C) kevin lenzo 1997-98

package Perlbot::Plugin::Math;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use Perlbot;
use Safe;

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
  $self->reply($result);
}

1;
