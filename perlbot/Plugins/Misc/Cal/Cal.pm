# Cal plugin
# Jeremy Muhlich jmuhlich@bitflood.org
# 
# updated: Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Cal;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot::Utils;

sub init {
  my $self = shift;

  $self->author('Andrew Burke');
  $self->contact('burke@bitflood.org');
  $self->version('1.0.0');
  $self->url('http://perlbot.sourceforge.net');

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

