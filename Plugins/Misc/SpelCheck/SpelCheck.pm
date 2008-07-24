# SpelCheck
# =========
#
# Jeremy Muhlich <jmuhlich@bitflood.org>
# Andrew Burke <burke@bitflood.org>
#
# Spell checks words using the Google API. 
# You must get a Google API key for this to work.
#

package Perlbot::Plugin::SpelCheck;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);

use Net::Google;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->hook('spell', \&spell);
}

sub set_initial_config_values {
  my $self = shift;

  $self->config->set('apikey', 'setmetosomethinguseful');

  return 1;
}

sub spell {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $google = Net::Google->new(key => $self->config->get('apikey'));

  my $result = $google->spelling(phrase => $text)->suggest();

  if(!$result) {
    $self->reply("All words checked out ok!");
  } else {
    $self->reply($result);
  }
}

1;
