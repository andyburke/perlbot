# Google Plugin
#
# You must get a google api key for this to work.

package Perlbot::Plugin::Google;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use Net::Google;

our $VERSION = '0.1.0';

sub init {
  my $self = shift;

  $self->hook('google', \&google);
}

sub google {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $google = new Net::Google(key => $self->config->value(google => 'apikey'));
  my $search = $google->search();

  $search->query($text);
  $search->max_results(1);

  my $result = shift @{$search->response()};
  my $data = shift @{$result->resultElements()};

  if(!$data) {
    $self->reply("No matches found for: $text");
  } else {
    $self->reply("$text: " . $data->URL());
  }
}
