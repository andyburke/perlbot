package Perlbot::Plugin::Outlander;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use Algorithm::MarkovChain;
use WWW::Babelfish;
use IPC::Open2;
use FileHandle;
use File::Spec;

our $VERSION = '0.2.0';

sub init {
  my $self = shift;

  $self->want_msg(0);
  $self->want_fork(0);

  $self->{chain} = new Algorithm::MarkovChain;
  $self->{symbols} = ();
  $self->seed();

  $self->hook(\&sodoit);

}

sub seed {
  my $self = shift;

  if(-f File::Spec->catfile($self->{directory}, 'knowledge')) {
    open(KNOWLEDGE, File::Spec->catfile($self->{directory}, 'knowledge'));
    my @lines = <KNOWLEDGE>;
    close KNOWLEDGE;

    foreach my $line (@lines) {
      push(@{$self->{symbols}}, split(' ', $line));
    }

    $self->{chain}->seed(symbols => $self->{symbols});

    $self->hook(\&sodoit);

  } else {
    return;
  }

}  

sub addline {
  my $self = shift;
  my $text = shift;

  chomp $text;

  open(KNOWLEDGE, '>>' . File::Spec->catfile($self->{directory}, 'knowledge'));
  print KNOWLEDGE $text . "\n";
  close(KNOWLEDGE);
}

sub sodoit {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;
  my $reply;

  my $curnick = $self->perlbot->curnick;

  my @words = split(' ', $text);
  my $length = scalar @words;
  $length = int($length * 1.5);
  undef @words;

  if($text !~ /$curnick/) {
    $text =~ s/^.*?(?:,|:)\s*//;

    my $starttime = time();
    my @response = $self->{chain}->spew(complete => $text, length => $length);
    $reply = "@response";
    chomp $reply;
    $reply = $self->babel($reply);

    if(int(rand(50)) == 25) {

      my $timediff = time() - $starttime;

      if($reply =~ /\&nbsp\;/ || length($reply) < 2) {
        $self->sodoit($user, $text, $event);
      }
      
      if($timediff > $self->delay($reply)) {
        $self->reply($reply);
      } else {
        sleep($self->delay($reply) - $timediff);
        $self->reply($reply);
      }
    }
  } else {
    my $regexp = $curnick . '(?:,|:|\.|\s)*';
    $text =~ s/^$regexp//i;
    my $theirnick = $event->nick;
    $text =~ s/$curnick/$theirnick/ig;

    my $starttime = time();
    my @response = $self->{chain}->spew(complete => $text, length => $length);
    $reply = "@response";
    chomp $reply;
    $reply = $self->babel($reply);
    my $timediff = time() - $starttime;
    
    if($reply =~ /\&nbsp\;/ || length($reply) < 2) {
      $self->sodoit($user, $text, $event);
    }
    
    if($timediff > $self->delay($reply)) {
      $self->addressed_reply($reply);
    } else {
      sleep($self->delay($reply) - $timediff);
      $self->addressed_reply($reply);
    }
  }

  $self->addline($text);
  $self->seed();
}

sub delay {
  my $self = shift;
  my $text = shift;

  return int(length($text) / 12);
}

sub babel {
  my $self = shift;
  my $text = shift;

  my $obj = new WWW::Babelfish( 'agent' => 'Perlbot/$VERSION');

  my @languages = ('German', 'French', 'English'); # $obj->languages();

  my $iterations = 3;

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

1;
