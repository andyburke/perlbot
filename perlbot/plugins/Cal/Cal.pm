# Cal plugin
# Jeremy Muhlich jmuhlich@bitflood.org
# 
# updated: Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Cal;

use Plugin;
@ISA = qw(Plugin);

use Perlbot::Utils;

sub init {
  my $self = shift;

  $self->hook('cal', \&host);
}

sub host {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @result = Perlbot::Utils::exec_command('cal', $text);

  foreach my $line (@result) {
    $self->reply($line);
  }
}

