package Perlbot::Plugin::Alarm;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use Perlbot;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->hook('alarm', \&alarm);
}

sub alarm {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($time, $message) = split(/ /, $text, 2);

  if(!defined($time) || !defined($message)) {
    $self->reply_error('You must specify a time and a message!');
    return;
  }

  my ($seconds, $minutes, $hours, $days) = reverse(split(':', $time));

  defined($days) or $days = 0;
  defined($hours) or $hours = 0;
  defined($minutes) or $minutes = 0;
  defined($seconds) or $seconds = 0;

  if($days + $hours + $minutes + $seconds < 1) {
    $self->reply_error('Your time must be in the future!');
    return;
  }

  my $actualtime = $seconds + (60 * $minutes) + (60 * 60 * $hours) + (24 * 60 * 60 * $days);

  $self->perlbot->schedule($actualtime, sub { $self->reply($message); });
  $self->reply('Alarm scheduled!');
}

1;
