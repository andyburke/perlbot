package Perlbot::Plugin::Test;

use Plugin;
@ISA = qw(Plugin);

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
