package Perlbot::Plugin::Test;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;

  use Data::Dumper;
  print Dumper($self->config);

}

sub test {
  my $self = shift;

  $self->reply('Saw my name!');
}
