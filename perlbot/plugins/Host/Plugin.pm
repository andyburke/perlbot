# Host plugin
# Andrew Burke burke@bitflood.org

package Host::Plugin;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use PerlbotUtils;

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

    my @result = PerlbotUtils::exec_command('host', $text);

    foreach my $line (@result) {
      $self->reply($line);
    }
  }
}

