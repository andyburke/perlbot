package Test::Plugin;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use PerlbotUtils;

sub init {
  my $self = shift;

  my $config = $self->read_config();

  use Data::Dumper;
  print Dumper($config);

}

sub test {
  my $self = shift;

  $self->reply('Saw my name!');
}
