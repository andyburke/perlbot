package Perlbot::Plugin::Outlander;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use WWW::Babelfish;

sub init {
  my $self = shift;

  $self->want_msg(0);

  $self->hook_addressed(\&addressed);
  $self->hook_regular_expression('.*', \&random);
}

sub addressed {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  $self->addressed_reply($self->babel($user, $text));
}

sub random {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $curnick = $self->{perlbot}{curnick};

  if($text !~ /$curnick/) {
    if(int(rand(20)) == 0) {
      $text =~ s/^.*?(?:,|:)\s*//;
      $self->reply($self->babel($user, $text));
    }
  }
}

sub babel {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  if($DEBUG) { print "Babelizing: $text\n"; }

  my $obj = new WWW::Babelfish( 'agent' => 'Perlbot/$VERSION');

  my @languages = ('German', 'French'); # $obj->languages();

  my $iterations = rand(100) % 3 + 3;

  my $source;
  my $dest;
  my $curresult = $text;

  for(my $i = 0; $i<$iterations; $i++) {
    if($i == 0) {
      $source = 'English';
      $dest = $languages[rand(20)%@languages];
    }

    if($i == $iterations - 1) {
      $dest = 'English';
    }

    if($obj && $curresult && $source && $dest) {
      $curresult = $obj->translate( 'source' => $source,
                                    'destination' => $dest,
                                    'text' => $curresult);
    }

    $source = $dest;
    $dest = $languages[rand(20)%@languages];
  }

  $curresult =~ s/\&nbsp\;//g; 
  return $curresult;
}
