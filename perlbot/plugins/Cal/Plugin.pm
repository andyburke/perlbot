# Cal plugin
# Jeremy Muhlich jmuhlich@bitflood.org
# 
# updated: Andrew Burke burke@bitflood.org

package Cal::Plugin;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use PerlbotUtils;

sub init {
  my $self = shift;

  $self->hook('cal', \&host);
}

sub host {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @result = PerlbotUtils::exec_command('cal', $text);

  foreach my $line (@result) {
    $self->reply($line);
  }
}

