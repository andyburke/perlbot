# Traceroute plugin
# Andrew Burke burke@bitflood.org

package Traceroute::Plugin;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use PerlbotUtils;

my $traceroutebinary = '/usr/sbin/traceroute';

sub init {
  my $self = shift;

  $self->hook('traceroute', \&host);
  $self->hook('tr', \&host);
}

sub host {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @result = PerlbotUtils::exec_command($traceroutebinary, $text);

  foreach my $line (@result) {
    $self->reply($line);
  }
}

