# Dig plugin
# Andrew Burke burke@bitflood.org

package Dig::Plugin;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use PerlbotUtils;

sub init {
  my $self = shift;

  $self->hook('dig', \&host);
}

sub host {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @result = PerlbotUtils::exec_command('dig', $text);

  foreach my $line (@result) {
    $self->reply($line);
  }
}

