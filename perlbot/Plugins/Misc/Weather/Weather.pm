# Andrew Burke <burke@pas.rochester.edu>
#
# Gets the weather...

package Perlbot::Plugin::Weather;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);

use Geo::Weather;
#use Weather::Underground;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->hook('weather', \&weather);
}

#sub weather {
#  my $self = shift;
#  my $user = shift;
#  my $text = shift;
#
#  my $weather = new Weather::Underground(place => "$text");
#  my $reports = $weather->getweather();
#  my $report = $reports->[0];
#
#  if(!defined($report)) {
#    $self->reply_error('Unable to get weather report!');
#    return;
#  } else {
#    my $conditions = $report->{conditions};
#    my $tempf = $report->{fahrenheit};
#    my $tempc = $report->{celsius};
#    my $humidity = $report->{humidity};
#
#    my @reply;
#
#    my $locline = "Location: " . $report->{place};
#    push(@reply, $locline);
#
#    my $currentline = "  Currently: $conditions ";
#    push(@reply, $currentline);
#
#    my $detailline;
#    if(defined($tempf)) { $detailline .= "  Temp: ${tempf}F"; }
#    if(defined($tempc)) { $detailline .= "(${tempc}C)"; }
#    if(defined($humidity)) { $detailline .= " Humidity: ${humidity}"; }
#    push(@reply, $detailline);
#
#    $self->reply(@reply);
#  }
#}

sub weather {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my ($origcity, $origstate) = split(',', $text);

  my $weather = new Geo::Weather();
  my $report = $weather->get_weather($origcity, $origstate);

  if(!ref($report)) {
    $self->reply_error('Unable to get weather report!');
    return;
  } else {


    my ($city, $state, $zip) = ($report->{city}, $report->{state}, $report->{zip});
    my $conditions = $report->{cond};
    my $tempf = $report->{temp};
    my $tempc;
    if(defined($tempf)) {
      $tempc = sprintf("%d", ($tempf - 32) * (5/9));
    }
    my ($heatindexf) = ($report->{heat} =~ /(\d+)/);
    my $heatindexc;
    if(defined($heatindexf)) {
      $heatindexc = sprintf("%d", ($heatindexf - 32) * (5/9));
    }
    my $wind = $report->{wind};
    my ($windm) = ($report->{wind} =~ /(\d+)/); $windm = sprintf("%d", $windm * 1.6);
    my $dewpointf = $report->{dewp};
    my $dewpointc;
    if(defined($dewpointf)) {
      $dewpointc = sprintf("%d", ($dewpointf - 32) * (5/9));
    }
    my $humidity = $report->{humi};
    
    my @reply;

    my $locline = "Location: ";
    if(defined($city)) { $locline .= "$city"; }
    if(defined($state)) { $locline .= ", $state"; }
    if(defined($zip)) { $locline .= " $zip"; }
    if(!defined($city) && !defined($state) && !defined($zip)) {
      if(defined($origcity)) { $locline .= "$origcity"; }
      if(defined($origstate)) { $locline .= ", $origstate"; }
    }
    push(@reply, $locline);

    my $currentline = "  Currently: $conditions ";
    if(defined($wind)) { $currentline .= "Wind: $wind "; }
    if(defined($windm)) { $currentline .= "(${windm}Kph)"; }
    push(@reply, $currentline);

    my $detailline;
    if(defined($tempf)) { $detailline .= "  Temp: ${tempf}F"; }
    if(defined($tempc)) { $detailline .= "(${tempc}C)"; }
    if(defined($heatindexf)) { $detailline .= " Heat Index: ${heatindexf}F"; }
    if(defined($heatindexc)) { $detailline .= "(${heatindexc}C)"; }
    if(defined($dewpointf)) { $detailline .= " Dewpoint: ${dewpointf}F"; }
    if(defined($dewpointc)) { $detailline .= "(${dewpointc}C)"; }
    if(defined($humidity)) { $detailline .= " Humidity: ${humidity}"; }
    push(@reply, $detailline);

    $self->reply(@reply);
  }
}

1;





