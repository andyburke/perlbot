# Andrew Burke <burke@pas.rochester.edu>
#
# Gets the weather...
#
# ported/mangled from:
#
# the original is back!
# weather.pl does what it says.. gets you the weather
# using www.weather.com, it brings you the local
# forecast minus the hassle at www.weather.com
# the only thing you need to edit is this:
# http://www.weather.com/weather/cities/us_ny_white_plains.html
# is the url for getting weather in the city of White Plains
# which is in the Sate of New York
# edit the $city and $state variables for your home city
# (use www.weather.com to find which is the one you want to go on)
# enjoy!   spline!spline@linuxwarez.com
# also look for my forecast.pl 

package Weather::Plugin;

use strict;

use Perlbot;

use Socket;
use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my $conn = shift;
  my $event = shift;
  my $args;

  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^${pluginprefix}weather/) {
    get_weather($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^${pluginprefix}weather/) {
    get_weather($conn, $event, $event->nick);
  }
}

sub get_weather {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $pid;

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in weather plugin...");
    return;
  }

  if($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my $args;
    $args = $event->{args}[0];
    $args =~ tr/[A-Z]/[a-z]/;
    $args =~ s/^${pluginprefix}weather\s*//;

    my $location = $args;
    $location =~ s/\s+/\+/g;       # for searches...
    $location =~ s/\,/\%2C/g;

    my($remote,$port,$iaddr,$paddr,$proto,$line);
    $remote = "www.weatherunderground.com";
    $port = "80";
    
    if(!defined($iaddr = inet_aton($remote))) {
      $conn->privmsg($who, "Could not get address of $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($paddr = sockaddr_in($port, $iaddr))) {
      $conn->privmsg($who, "Could not get port address of $remote");
      $conn->{_connected} = 0;
      exit 1;
    }      
    if(!defined($proto = getprotobyname('tcp'))) {
      $conn->privmsg($who, "Could not get tcp connection for $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    
    if(!socket(SOCK, PF_INET, SOCK_STREAM, $proto)) {
      $conn->privmsg($who, "Could not establish socket connect to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!connect(SOCK, $paddr)) {
      $conn->privmsg($who, "Could not establish connection to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    my $msg = "GET /cgi-bin/findweather/getForecast?query=${location} HTTP/1.0\n\n";

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($who, "Could not establish send to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }


    my $hrm;
    while(<SOCK>) { $hrm .= $_; }

    if ($hrm =~ /.*error\:\s*not found/i) {
      $conn->privmsg($who, "No weather matches found for $args");
      $conn->{_connected} = 0;
      exit 0;
    }
    
    my($update, $temp, $windchill, $humidity, $wind, $bar, $conditions, $visibility, $sunrise, $sunset);

    if($hrm =~ /Search For:/i) {
      $conn->privmsg($who, "Best Guess for $args:");
      
      ($location) = ($hrm =~ /Warning.*?Favorites.*?\n*.*?\<a.*?>(.*?)<\/a>/i);
      ($temp) = ($hrm =~ /$location.*?(.*?\&\#176)/i); $temp =~ s/\<.*?\>//g; $temp =~ s/\&\#176//g;
      ($humidity) = ($hrm =~ /$location.*?(\d+\%)/i);
      ($bar) = ($hrm =~ /$location.*?(\d+\.\d+.*?\s+in)/i);

    } else {

      ($update) = ($hrm =~ /Updated:.*?\<.*?\>(.*?)\<.*?\>/i);
      ($location) = ($hrm =~ /\<.*?AirportMenu.*?\>.*?\n*.*?\<.*?SELECTED.*?\>(.*?)\<.*?\>/i);
      ($temp) = ($hrm =~ /Temperature.*?\n*(.*?\&\#176)/i); $temp =~ s/\<.*?\>//g; $temp =~ s/\&\#176//g;
      ($windchill) = ($hrm =~ /Windchill.*?\n*(.*?\&\#176)/i); $windchill =~ s/\<.*?\>//g; $windchill =~ s/\&\#176//g;
      ($humidity) = ($hrm =~ /Humidity.*?\n*.*?(\d+\%)/i);
      ($wind) = ($hrm =~ /Wind.*?\n*(.*?mph)/i); $wind =~ s/\<.*?\>//g;
      ($bar) = ($hrm =~ /Pressure.*?\n*.*?(.*?in)/i); $bar =~ s/\<.*?\>//g;
      ($conditions) = ($hrm =~ /Conditions.*?\n*.*?\<b\>(.*?)\<\/b\>.*?\n*/i); $conditions =~ s/\<.*?\>//g;
      ($visibility) = ($hrm =~ /Visibility.*?\n*.*?(.*?miles)/i); $visibility =~ s/\<.*?\>//g;
      ($sunrise) = ($hrm =~ /Sunrise.*?(.*?)\n/i); $sunrise =~ s/\<.*?\>//g;
      ($sunset) = ($hrm =~ /Sunset.*?(.*?)\n/i); $sunset =~ s/\<.*?\>//g;
    
    }
#ok done getting the info..
    #be nice to people using the right system...

    my $celsius = ($temp - 32) * (5/9);
    $celsius = sprintf("%.2f", $celsius);

    my $celsius_wind = ($windchill - 32) * (5/9);
    $celsius_wind = sprintf("%.2f", $celsius_wind);

    my ($kph) = $wind =~ /at (\d+) mph/;
    $kph = 1.6 * $kph;

    my ($metric_bar) = $bar =~ /(.*?)\s+/;
    $metric_bar = 2.54 * $metric_bar;

    $conn->privmsg($who, "${location} (observation point closest to area):");
    if($update) { $conn->privmsg($who, "Last Updated: $update"); }
    if($sunrise && $sunset) { $conn->privmsg($who, "Sunrise/Sunset: $sunrise / $sunset\n"); }
    if($conditions) { $conn->privmsg($who, "Current Conditions: $conditions"); }
    if($visibility) { $conn->privmsg($who, "Visibility: $visibility"); }
    if($temp) { $conn->privmsg($who, "Temp: ${temp}F (${celsius}C)"); }
    if($windchill) { $conn->privmsg($who, "Windchill: ${windchill}F (${celsius_wind}C)"); }
    if($wind) { $conn->privmsg($who, "Wind: $wind ($kph kph)"); }
    if($humidity && $bar) { $conn->privmsg($who, "Humidity: $humidity / Barometer: $bar ($metric_bar cm)"); }

    $conn->{_connected} = 0;
    exit 0;
  }
}

1;





