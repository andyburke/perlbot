package Perlbot::Plugin::URLEater;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);
use fields qw(urls);

use DB_File;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_fork(0);
  
  tie @{$self->{urls}},  'DB_File', File::Spec->catfile($self->{directory}, 'urldb'), O_CREAT|O_RDWR, 0640, $DB_RECNO;
  if(length(@{$self->{urls}}) == 1) {
    push(@{$self->{urls}}, 'this is a crappy hack to make unshift work');
  }

  $self->hook_event('public', \&eaturl);
  $self->hook('urls', \&regurgitate);
  $self->hook_web('urls', \&regurgitate_web, 'Recent URLs');
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
      pop @{$self->{urls}};
    }
    unshift(@{$self->{urls}}, $urltostore);      
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

  if($max > 10) { $max = 10; }

  my $printed = 0;
  my @reply;

  foreach my $storedurl (@{$self->{urls}}) {
    my ($channel, $nick, $time, $url) = split('::::', $storedurl);
    if($channel eq $chan) {
      unshift(@reply, $url . ' -- ' . $nick); # . ' -- ' . localtime($time));
      $printed++;
    }
    if($printed >= $max) { last; }
  }

  $self->reply(@reply);
}

sub regurgitate_web {
  my $self = shift;
  my @args = @_;

  my %urls;

  my $response = "<html><head><title>URLs</title></head><body>";

  foreach my $storedurl (@{$self->{urls}}) {
    my ($channel, $nick, $time, $url) = split('::::', $storedurl);
    push(@{$urls{$channel}}, [$nick, $time, $url]);
  }

  foreach my $channel (keys(%urls)) {
    if($channel =~ /\s/) { next; }
    $response .= "<p><b>$channel:</b><p>";
    my @urls;
    for(my $i = 0; $i < 5; $i++) {
      if(defined($urls{$channel}[$i])) {
        my ($nick, $time, $url) = @{$urls{$channel}[$i]};
        unshift @urls, "<a href=\"$url\">$url</a> -- $nick<br>";
      }
    }
    foreach my $url (@urls) {
      $response .= $url;
    }
  }

  $response .= "</body></html>";

  return ('text/html', $response);
}

1;
      







