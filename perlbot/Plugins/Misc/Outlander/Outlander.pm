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
  $self->{lastseedtime} = time();

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

  open(KNOWLEDGE, '>>' . File::Spec->catfile($self->{directory}, 'learned_knowledge'));
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
  if((rand()*10)/ 2 == 0) {
    $length = int($length * 1.2);
  } else {
    $length = int($length * .75);
  }
  if($length < 1) { $length = 1; }
  undef @words;

  if($text !~ /$curnick/i) {
    if(int(rand(20)) == 10) {
      $text =~ s/^.*?(?:,|:)\s*//;

      my $starttime = time();
      my @response = $self->{chain}->spew(complete => $text, length => $length);
      $reply = "@response";
      chomp $reply;
      my $endchar;
      my $endchardeterminer = int(rand(10));
      if($endchardeterminer % 3 == 0) {
        $endchar = '!';
      } elsif($endchardeterminer % 2 == 0) {
        $endchar = '?';
      } else {
        $endchar = '.';
      }
      $reply = $reply . $endchar;
      $reply = $self->babel($reply);

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
    my $endchar;
    my $endchardeterminer = int(rand(10));
    if($endchardeterminer % 3 == 0) {
      $endchar = '!';
    } elsif($endchardeterminer % 2 == 0) {
      $endchar = '?';
    } else {
      $endchar = '.';
    }
    $reply = $reply . $endchar;
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

  if(length($text) > 50) {
    $self->addline($text);
  }
  if(time() - $self->{lastseedtime} > 86400) {
    $self->seed();
    $self->{lastseedtime} = time();
  }
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
