# Traceroute plugin
# Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Traceroute;

use Plugin;
@ISA = qw(Plugin);

use Perlbot::Utils;

sub init {
  my $self = shift;

  $self->{traceroutebinary} = '/usr/sbin/traceroute';

  $self->hook('traceroute', \&host);
  $self->hook('tr', \&host);
}

sub host {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @result = Perlbot::Utils::exec_command($self->{traceroutebinary}, $text);

  foreach my $line (@result) {
    $self->reply($line);
  }
}

