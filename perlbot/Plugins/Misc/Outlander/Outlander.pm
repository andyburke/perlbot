package Perlbot::Plugin::Outlander;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);
use fields qw(chain symbols lastseedtime);

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
  my $lengthchangedeterminer = int(rand(10));
  if($lengthchangedeterminer == 7) {
    $length = int($length / 3);
  } elsif($lengthchangedeterminer % 2 == 0) {
    $length = int($length * 1.1);
  } else {
    $length = int($length * .75);
  }
  if($length < 1) { $length = 1; }
  if($length > 15) { $length = 15; }
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
        if(int(rand(10)) % 2 == 0) {
          $self->addressed_reply($reply);
        } else {
          $self->reply($reply);
        }
      } else {
        sleep($self->delay($reply) - $timediff);
        if(int(rand(10)) % 2 == 0) {
          $self->addressed_reply($reply);
        } else {
          $self->reply($reply); 
        }
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
#    $reply = $reply . $endchar;
    $reply = $self->babel($reply);
    my $timediff = time() - $starttime;
    
    if($reply =~ /\&nbsp\;/ || length($reply) < 2) {
      $self->sodoit($user, $text, $event);
    }
    
    if($timediff > $self->delay($reply)) {
      my $replyorder = int(rand(10));
      if($replyorder == 7) { # 1/10 chance
        $self->reply($reply . $endchar); # don't put on a nick
      } elsif($replyorder % 3 == 0) { # ~ 1/3 chance
        $self->reply($reply . ", $theirnick" . $endchar); # put their nick on the end
      } else { # the rest
        $self->addressed_reply($reply . $endchar);
      }
    } else {
      sleep($self->delay($reply) - $timediff);
      my $replyorder = int(rand(10));
      if($replyorder == 7) { # 1/10 chance
        $self->reply($reply . $endchar); # don't put on a nick
      } elsif($replyorder % 3 == 0) { # ~ 1/3 chance
        $self->reply($reply . ", $theirnick" . $endchar); # put their nick on the end
      } else { # the rest
        $self->addressed_reply($reply . $endchar);
      }
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

  return int(length($text) / 5);
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
