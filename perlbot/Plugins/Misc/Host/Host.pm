# Host plugin
# Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Host;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot::Utils;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

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

