# Andrew Burke <burke@pas.rochester.edu>
#
# Gets the weather...

package Perlbot::Plugin::Weather;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use Geo::Weather;

sub init {
  my $self = shift;

  $self->author('Andrew Burke');
  $self->contact('burke@bitflood.org');
  $self->version('1.0.0');
  $self->url('http://perlbot.sourceforge.net');

  $self->hook('weather', \&weather);
}

sub weather {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my ($city, $state) = split(',', $text);

  my $weather = new Geo::Weather();
  my $report = $weather->get_weather($city, $state);

  if(!ref($report)) {
    $self->reply_error('Unable to get weather report!');
    return;
  } else {

    my ($city, $state, $zip) = ($report->{city}, $report->{state}, $report->{zip});
    my $conditions = $report->{cond};
    my $tempf = $report->{temp};
    my $tempc = sprintf("%d", ($tempf - 32) * (5/9));
    my ($heatindexf) = ($report->{heat} =~ /(\d+)/);
    my $heatindexc = sprintf("%d", ($heatindexf - 32) * (5/9));
    my $wind = $report->{wind};
    my ($windm) = ($report->{wind} =~ /(\d+)/); $windm = sprintf("%d", $windm * 1.6);
    my $dewpointf = $report->{dewp};
    my $dewpointc = sprintf("%d", ($dewpointf - 32) * (5/9));
    my $humidity = $report->{humi};
    my $barometer = $report->{baro};
    my $barometerm = sprintf("%.2f", $barometer * 2.54);
    my $visibility = $report->{visb};
    my $visibilitym = sprintf("%d", $visibility * 1.6);
    
    $self->reply("Location: $city, $state $zip");
    $self->reply("  Currently: $conditions");
    $self->reply("  Temperature: ${tempf}F (${tempc}C)");
    $self->reply("  Heat Index \"Feels Like\": ${heatindexf}F (${heatindexc}C)");
    $self->reply("  Wind: $wind (${windm}Kph)");
    $self->reply("  Dewpoint: ${dewpointf}F (${dewpointc}C) Humidity: ${humidity}% Barometer: ${barometer}in (${barometerm}cm)");
    if($visibility =~ /\d+/) {
      $self->reply("  Visibility: ${visibility}Mi (${visibilitym}Km)");
    } else {
      $self->reply("  Visibility: $visibility");
    }
  }
}
1;





