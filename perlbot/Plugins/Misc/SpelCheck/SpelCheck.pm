# SpelCheck
# =========
#
# Jeremy Muhlich <jmuhlich@jhu.edu>
#
# This plugin does spell-checking using ispell.  Prolly needs to be on
# a unix system...
#
# based on:
# infobot copyright (C) kevin lenzo 1997-98

package Perlbot::Plugin::SpelCheck;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use Net::Google;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->hook('spell', \&spell);
}

sub spell {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $google = Net::Google->new(key => $self->config->value(google => 'apikey'));

  my $result = $google->spelling(phrase => $text)->suggest();

  if(!$result) {
    $self->reply("All words checked out ok!");
  } else {
    $self->reply($result);
  }
}

1;
