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

  $self->{stylefile} = File::Spec->catfile($self->{directory}, 'perlbot.css');

  $self->hook_web('perlbot.css', \&servecss, 'Site-Wide Style Sheet');
}

sub servecss {
  my $self = shift;
  my @args = @_;

  my $css;
  open(CSS, $self->{stylefile});
  while(my $line = <CSS>) {
    chomp $line;
    $css .= $line;
  }
  close(CSS);
  return ('text/css', $css);
}

1;
















