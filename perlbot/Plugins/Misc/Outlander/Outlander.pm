package Perlbot::Plugin::Outlander;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use WWW::Babelfish;
use MegaHAL;

our $VERSION = '0.2.0';

sub init {
  my $self = shift;

  $self->want_msg(0);

  $self->{megahal} = new MegaHAL('Path'     => $self->directory,
                                 'Banner'   => 0,
                                 'Prompt'   => 0,
                                 'Wrap'     => 0,
                                 'AutoSave' => 1);
  $self->megahal->initial_greeting();

  $self->{confused} = ['what?',
                       'sorry, understanding is not easy for me',
                       'I am afflicted, which?',
                       'I do not include/understand',
                       'I have a comprehension of time lasts you',
                       'slow down you, you are confusing me!',
                       'I am much konfus',
                       'I do not understand'
                       ];

  $self->hook(\&sodoit);

}

sub megahal {
  my $self = shift;
  return $self->{megahal};
}

sub sodoit {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;

  my $curnick = $self->perlbot->curnick;

  if($text !~ /$curnick/) {
    if(int(rand(50)) == 25) {
      $text =~ s/^.*?(?:,|:)\s*//;

      my $starttime = time();
      print "text: $text\n";
      my $reply = $self->megahal->do_reply($text);
      print "reply: $reply\n";
      $reply = $self->babel($reply);
      print "after babel: $reply\n";
      my $timediff = time() - $starttime;

      if($reply =~ /\&nbsp\;/ || length($reply) < 2) {
#        my $reply = $self->{confused}[int(rand(100))%@{$self->{confused}}];
#        sleep($self->delay($reply));
#        $self->reply($reply);
#        return;
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
    print "text: $text\n";
    my $reply = $self->megahal->do_reply($text);
    print "reply: $reply\n";
    $reply = $self->babel($reply);
    print "after babel: $reply\n";
    my $timediff = time() - $starttime;
    
    if($reply =~ /\&nbsp\;/ || length($reply) < 2) {
#      my $reply = $self->{confused}[int(rand(100))%@{$self->{confused}}];
#      sleep($self->delay($reply));
#      $self->reply($reply);
#      return;
      $self->sodoit($user, $text, $event);
    }
    
    if($timediff > $self->delay($reply)) {
      $self->addressed_reply($reply);
    } else {
      sleep($self->delay($reply) - $timediff);
      $self->addressed_reply($reply);
    }
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
