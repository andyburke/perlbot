# Perldoc
# Andrew Burke burke@bitflood.org

package Perldoc::Plugin;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use PerlbotUtils;

sub init {
  my $self = shift;

  $self->hook('perldoc', \&perldoc);
}

sub perldoc {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($max) = ($text =~ /(\d+)\s*$/);
  $text =~ s/\d+\s*$//;

  $max ||= 10;

  my @result = PerlbotUtils::exec_command('perldoc', $text);

  my $linenum = 0;
  foreach my $line (@result) {
    if($linenum <= $max) {
      $self->reply($line);
    } else {
      $self->reply('[[ ' . (@result - $linenum) . ' lines not displayed ]]');
      last;
    }
    $linenum++;
  }
}

