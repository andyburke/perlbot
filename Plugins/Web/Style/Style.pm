# Style 
#
# by Andrew Burke (burke@bitflood.org)
#

package Perlbot::Plugin::Style;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);
use fields qw(stylefile);

use XML::Simple;
use Perlbot::Utils;
use File::Spec;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->hook_web('perlbot.css', \&servecss, 'Site-Wide Style Sheet');
}

sub set_initial_config_values {
  my $self = shift;

  $self->config->set('css-file', File::Spec->catfile($self->{directory}, 'perlbot.css'));

  return 1;
}


sub servecss {
  my $self = shift;
  my @args = @_;

  my $css;
  open(CSS, $self->config->get('css-file'));
  while(my $line = <CSS>) {
    chomp $line;
    $css .= $line;
  }
  close(CSS);
  return ('text/css', $css);
}

1;
















