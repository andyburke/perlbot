# Dig plugin
# Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Dig;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot::Utils;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->hook('dig', \&host);
}

sub host {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @result = Perlbot::Utils::exec_command('dig', $text);

  foreach my $line (@result) {
    $self->reply($line);
  }
}

