# Google Plugin
#
# You must get a google api key for this to work.

package Perlbot::Plugin::Google;

use strict;
use Perlbot::Plugin;
use Perlbot::Utils;
use base qw(Perlbot::Plugin);

use Net::Google;

our $VERSION = '0.1.0';

sub init {
  my $self = shift;

  $self->hook('google', \&google);
}

sub set_initial_config_values {
  my $self = shift;

  $self->config->set('apikey', 'setmetosomethinguseful');

  return 1;
}

sub google {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $google = new Net::Google(key => $self->config->get('apikey'));
  my $search = $google->search();

  $search->query($text);
  $search->max_results(1);

  my $result = shift @{$search->response()};
  
  if(!$result) {
    $self->reply("No matches found for: $text");
    return;
  }

  my $data = shift @{$result->resultElements()};

  $self->reply("$text: " . $data->URL());
}

1;
