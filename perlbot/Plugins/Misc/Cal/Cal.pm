# Cal plugin
# Jeremy Muhlich jmuhlich@bitflood.org
# 
# updated: Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Cal;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot::Utils;
use Calendar::Simple;

our $VERSION = '2.0.0';

sub init {
  my $self = shift;

  $self->hook('cal', \&cal);
  $self->hook('calendar', \&cal);
}

sub cal {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($mon, $yr) = split(/ /, $text);

  defined($mon) or $mon = (localtime)[4] + 1;
  defined($yr) or $yr = (localtime)[5] + 1900;

  if($yr < 1970) {
    $self->reply_error("$yr is out of range!");
    return;
  }

  my @result;

  my @months = qw(January February March April May June July August September October November December);

  my @month = calendar($mon, $yr);

  my $header = $months[$mon - 1] . " $yr";
  my $difference = 20 - length($header);  # for centering

  my $headerline;
  for(my $i = 0; $i < $difference / 2; $i++) {
    $headerline .= ' ';
  }
  $headerline .= $header;

  push(@result, $headerline);
  push(@result, "Su Mo Tu We Th Fr Sa");
  foreach my $line (@month) {
    my $weekline;
    foreach my $day (@{$line}) {
      if(defined($day)) {
        $weekline .= sprintf("%2d ", $day);
      } else {
        $weekline .= '   ';
      }
    }
    push(@result, $weekline);
  }

  $self->reply(@result);
}


