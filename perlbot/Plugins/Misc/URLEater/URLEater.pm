package Perlbot::Plugin::URLEater;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;
use DB_File;

sub init {
  my $self = shift;

  $self->author('Andrew Burke');
  $self->contact('burke@bitflood.org');
  $self->version('1.0.0');
  $self->url('http://perlbot.sourceforge.net/');

  $self->want_fork(0);
  
  tie @{$self->{urls}},  'DB_File', File::Spec->catfile($self->{directory}, 'urldb'), O_CREAT|O_RDWR, 0640, $DB_RECNO;

  $self->hook_event('public', \&eaturl);
  $self->hook('urls', \&regurgitate);
}

sub eaturl {
  my $self = shift;
  my $event = shift;
  my $nick = $event->nick();
  my $channel = $event->{to}[0];
  my $text = $event->{args}[0];

  if($text =~ /http:\/\//) {
    my ($url) = $text =~ /(http:\/\/.*?)(?:\s+|$)/;
    my $urltostore = $channel . '::::' . $nick . '::::' . time() . '::::' . $url;
    if(length(@{$self->{urls}}) > 100) {
      shift @{$self->{urls}};
    }
    push(@{$self->{urls}}, $urltostore);      
  }
}

sub regurgitate {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;
  my $chan = $event->{to}[0];

  my ($max) = $text =~ /(\d+)/;
  $max ||= 5;

  my $printed = 0;
  my @reply;

  foreach my $storedurl (@{$self->{urls}}) {
    my ($channel, $nick, $time, $url) = split('::::', $storedurl);
    if($channel eq $chan) {
      push(@reply, $url . ' / ' . $nick . ' / ' . localtime($time));
      $printed++;
    }
    if($printed >= $max) { last; }
  }

  $self->reply(@reply);
}



