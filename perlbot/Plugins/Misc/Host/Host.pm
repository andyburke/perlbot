# Host plugin
# Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Host;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot::Utils;

sub init {
  my $self = shift;

  $self->author('Andrew Burke');
  $self->contact('burke@bitflood.org');
  $self->version('1.0.0');
  $self->url('http://perlbot.sourceforge.net');

  $self->hook('host', \&host);
  $self->hook('nslookup', \&host);
}

sub host {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  if(!$text) {
    $self->reply('You must specify a hostname to look up!');
  } else {

    my @result = Perlbot::Utils::exec_command('host', $text);

    foreach my $line (@result) {
      $self->reply($line);
    }
  }
}

