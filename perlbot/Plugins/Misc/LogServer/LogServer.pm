# Andrew Burke <burke@bitflood.org>
#
# Man, this is way bigger than I thought it would be
#
# This is a combination of a bunch of people's work,
# including Jeremy Muhlich <jmuhlich@bitflood.org> and
# Phil Fibiger <philip@fibiger.org>
#
# TODO: make it use channel keys for password protection of the logs... ?
#       make this thing die cleanly

package Perlbot::Plugin::LogServer;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);
use Perlbot::Utils;

use Time::Local;

use CGI qw(:standard);

our $VERSION = '0.3.1';

sub init {
  my $self = shift;

  $self->want_msg(0);
  $self->want_public(0);
  
  $self->hook_web('logserver', \&logserver, 'Channel Logs');
}

sub set_initial_config_values {
  my $self = shift;

  $self->config->set('allowsearchengines', 'no');
  $self->config->set('authtyperequired', 'user');

  return 1;
}

sub logserver {
  my $self = shift;
  my $arguments = shift;

  my $response = '<html><head><title>Perlbot Logs</title>';
 
  if (lc($self->config->get('allowsearchengines')) eq 'yes') {
     # don't bother adding the meta tag to disallow archiving
  } else {
    $response .= '<meta name="ROBOTS" content="NOINDEX, NOFOLLOW, NOARCHIVE" />';
  }

  $response .= '<link rel="stylesheet" href="/perlbot.css" type="text/css" />';
#  $response .= '
#
#  </head>
#  <body>
#    <div style="width: 99%; border-bottom: 1px solid;">
#      <table border="0" width="99%"><tr>
#        <td width="50%">
#          <div style="text-align: left; font-size: x-large; font-weight: bold;">Perlbot Logs</div>
#        </td>
#        <td width="50%">
#';
  $response .= '

  </head>
  <body>
    <div style="width: 99%; border-bottom: 1px solid;">
      <span style="width: 50%; text-align: left; font-size: x-large; font-weight: bold;">Perlbot Logs</span>
';

        
  my ($command, $options_string) = $arguments =~ /^(.*?)\?(.*)$/;

  my $options;

  foreach my $option (split('&', $options_string)) {
    my ($key, $value) = $option =~ /^(.*?)=(.*)$/;
    $options->{$key} = $value;
  }

  if($options->{channel}) {
    $response .= "      <span style=\"text-align: right;\"><a href=\"/logserver/search?channel=" . $options->{channel} . "\">[search]</a> <a href=\"/logserver/display?channel=" . $options->{channel} . "\">[" . $options->{channel} . "]</a> <a href=\"/logserver\">[top]</a></span>";
  }

  $response .= '</div><p>';

  if(!$command) {
    $response .= '<ul>';

    foreach my $channel (values(%{$self->perlbot->channels})) {
      if($channel->config->get(channel => $channel->name => 'logging') eq 'yes') {
        $response .= "<li><b><a href=\"/logserver/display?channel=" . strip_channel($channel->name) . "\">" . strip_channel($channel->name) . "</a></b>";
      }
    }
    
    $response .= '</ul>';

    return $self->std_response($response);
  }
  
  if($command && $command eq 'display') {

    if(!$options->{channel}) {
      return $self->std_response($response . "<b>You must specify a channel!</b>");
    }

    my $channel = $self->perlbot->get_channel($options->{channel});

    if(!$options->{year}) { # they need to choose a year
      $response .= '<ul>';

      my $initialyear = (localtime($channel->logs->initial_entry_time()))[5] + 1900;
      my $finalyear = (localtime($channel->logs->final_entry_time()))[5] + 1900;
    
      for my $year ($initialyear..$finalyear) {
        $response .= "<li><b><a href=\"/logserver/display?channel=" . $options->{channel} . "&year=$year\">$year</a></b></li>";
      }

      return $self->std_response($response);
    }

    if(!$options->{month}) { # they haven't chosen a month or day
      use HTML::CalendarMonth;
    
      my $year = $options->{year};

      $response .= '<div style="width: 99%; border-bottom: 1px solid;">';
      $response .= "<b>#" . $options->{channel} . " logs for $year<b>\n";
      $response .= '</div><br>';

      $response .= '

        <style type="text/css">
        <!--

          table {
          }

          tr {
            height: 1.2em;
          }

          td {
            width: 1.5em;
          }

          table.main {
          }

          tr.main {
            height: 33%;
          }

          td.main {
            width: 25%;
            vertical-align: top;
            text-align: left;
            padding: 5px;
          }

        -->
        </style>';


      $response .= "<center><table class=\"main\">\n";

      $response .= "  <tr class=\"main\">\n";
      foreach my $month ((1..12)) {
        $response .= "    <td class=\"main\">\n";
        $month = sprintf("%02d", $month);

        my $cal = HTML::CalendarMonth->new(year => $year, month => $month, head_y =>0, class => 'table');

        $cal->item($cal->month)->attr(class => 'tableheader');
        foreach my $day_header ($cal->dayheaders()) {
          $cal->item($day_header)->attr(class => 'tablesubheader');
        }
        
        foreach my $day ($cal->days()) {
          if($channel->logs->search({
            initialdate
                => timegm(0, 0, 0, $day, $month - 1, $year - 1900),
            finaldate
                => timegm(59, 59, 23, $day, $month - 1, $year - 1900),
            boolean
                => 1
              })) {
            
            my $padded_day = sprintf("%02d", $day);
            print "linking day: $padded_day\n";
            $cal->item($day)->wrap_content(HTML::Element->new('a',
                                                              href => "/logserver/display?channel="
                                                              . $options->{channel}
                                                              . "&year=${year}&month=${month}&day=${padded_day}"));
          }
        }
        $response .= "      " . $cal->as_HTML();
        $response .= "    </td>\n";
        if($month % 4 == 0) { $response .= "  </tr>\n  <tr class=\"main\">\n"; }
      }
      $response .= "</table></center>\n";

      return $self->std_response($response);
    }

    if(defined($options->{day}) && defined($options->{month}) && defined($options->{year})) {
      my @events = $channel->logs->search({ initialdate
                                                => timegm(0, 0, 0, $options->{day}, $options->{month} - 1, $options->{year} - 1900),

                                            finaldate
                                                => timegm(59, 59, 23, $options->{day}, $options->{month} - 1, $options->{year} - 1900)
                                              });

      if(!@events) {
        $response .= "<center>
                        <h2>
                          No logs for "
                          . $options->{year}
                          . "/"
                          . $options->{month}
                          . "/"
                          . $options->{day}
                          . "!
                        </h2>
                      </center>";
        return $self->std_response($response);
      }

      foreach my $event (@events) {
        $response .= $self->event_as_html_string($event);
      }

      return $self->std_response($response);
    }

  }
  
  if($command && $command eq 'search') {
    
    if(!$options->{channel}) {
      return $self->std_response($response . "<b>You must specify a channel!</b>");
    }

    my $channel = $self->perlbot->get_channel($options->{channel});

    if(!defined($options->{submit})) {
      $response .= "<h2>Search logs for channel: " . $options->{channel} . "</h2><p>";
      $response .= "<form method=\"get\" action=\"/logserver/search\">";
      $response .= "<input type=\"hidden\" name=\"channel\" value=\"" . $options->{channel} . "\">";
      $response .= "Enter words to search for: <input type=\"text\" name=\"terms\"  /><br/>";
      $response .= "Enter nickname to search for: <input type=\"text\" name=\"nick\"  /><br/>";
      $response .= "Event type: <select name=\"type\">
                                  <option>all</option>
                                  <option>public</option>
                                  <option>caction</option>
                                  <option>nick</option>
                                  <option>topic</option>
                                  <option>mode</option>
                                  <option>join</option>
                                  <option>part</option>
                                  <option>kick</option>
                                  <option>quit</option>
                                </select><br/>";

      $response .= "Initial Date: <select name=\"initialyear\">";

        my $initialyear = (localtime($channel->logs->initial_entry_time()))[5] + 1900;
        my $finalyear = (localtime($channel->logs->final_entry_time()))[5] + 1900;

        for my $year ($initialyear..$finalyear) {
          if($year == $initialyear) {
            $response .= "<option selected=\"1\">$year</option>";
          } else {
            $response .= "<option>$year</option>";
          }
        }

      $response .= "</select>"; # end year selection

      $response .= "<select name=\"initialmonth\">";

        $response .= "<option selected=\"1\">1</option>";
        foreach my $mon (2..12) {
          $response .= "<option>$mon</option>";
        }

      $response .= "</select>"; # end month selection

      $response .= "<select name=\"initialday\">";

        $response .= "<option selected=\"1\">1</option>";
        foreach my $day (2..31) {
          $response .= "<option>$day</option>";
        }

      $response .= "</select>"; # end day selection

      $response .= "h: <input type=\"text\" name=\"initialhour\" size=\"2\">";
      $response .= "m: <input type=\"text\" name=\"initialmin\" size=\"2\">";
      $response .= "s: <input type=\"text\" name=\"initialsec\" size=\"2\"><br/>";

      $response .= "Final Date: <select name=\"finalyear\">";

        for my $year ($initialyear..$finalyear) {
          if($year == $finalyear) {
            $response .= "<option selected=\"1\">$year</option>";
          } else {
            $response .= "<option>$year</option>";
          }
        }

      $response .= "</select>"; # end year selection

      $response .= "<select name=\"finalmonth\">";

        foreach my $mon (1..11) {
          $response .= "<option>$mon</option>";
        }
        $response .= "<option selected=\"1\">12</option>";
      
      $response .= "</select>"; # end month selection

      $response .= "<select name=\"finalday\">";

        foreach my $day (1..30) {
          $response .= "<option>$day</option>";
        }
        $response .= "<option selected=\"1\">31</option>";

      $response .= "</select>"; # end day selection

      $response .= "h: <input type=\"text\" name=\"finalhour\" size=\"2\">";
      $response .= "m: <input type=\"text\" name=\"finalmin\" size=\"2\">";
      $response .= "s: <input type=\"text\" name=\"finalsec\" size=\"2\"><br/>";
      
      

      $response .= "<input type=\"submit\" name=\"submit\" />";
      $response .= "</form>";

      $response .= "<font size=\"-1\" color=\"red\">* Note that search speed is often dependent on many factors, including the amount of data logged and the log facility the bot administrator has chosen.  Please allow ample time for the search to complete.</font>";

      return $self->std_response($response);
      
    } else {
      
      my @terms = split(/\+/, $options->{terms});

      my $initialyear = $options->{initialyear};
      my $initialmonth = $options->{initialmonth};
      my $initialday = $options->{initialday};
      my $initialhour = $options->{initialhour} || 0;
      my $initialmin = $options->{initialmin} || 0;
      my $initialsec = $options->{initialsec} || 0;
      my $initialdate = timegm($initialsec, $initialmin, $initialhour, $initialday, $initialmonth - 1, $initialyear - 1900);

      my $finalyear = $options->{finalyear};
      my $finalmonth = $options->{finalmonth};
      my $finalday = $options->{finalday};
      my $finalhour = $options->{finalhour} || 23;
      my $finalmin = $options->{finalmin} || 59;
      my $finalsec = $options->{finalsec} || 59;
      my $finaldate = timegm($finalsec, $finalmin, $finalhour, $finalday, $finalmonth - 1, $finalyear - 1900);

      my $nick = $options->{nick};
      my $type = $options->{type}; if($type eq 'all') { $type = undef; };

      my @events = $channel->logs->search({ terms => \@terms,
                                            initialdate => $initialdate,
                                            finaldate => $finaldate,
                                            nick => $nick,
                                            type => $type });

      # if we get no results...
      if(!@events) {
        $response .= "No results found!";
        return $self->std_response($response);
      }

      # otherwise, we have some results for them...
      my ($year, $month, $day) = (0, 0, 0);
      foreach my $event (@events) {
        my $datestring = "$year.$month.$day";
        # why can't localtime be sane?
        my (undef, undef, undef, $event_day, $event_month, $event_year) = localtime($event->time());
        $event_year += 1900;
        $event_month = sprintf("%02d", $event_month + 1);
        $event_day = sprintf("%02d", $event_day);

        my $channel_name = $options->{channel};

        if($datestring ne "$event_year.$event_month.$event_day") {
          $year = $event_year;
          $month = $event_month;
          $day = $event_day;
          $datestring = "$year.$month.$day";

          $response .= "<p class=\"dateheader\">
                        <a style=\"text-decoration: none; color: black; border-bottom: 1px dotted;\" href=\"/logserver/display?channel=$channel_name&year=$year&month=$month&day=$day\">$datestring</a><p class=\"block\">";
        }

        my $event_string .= $self->event_as_html_string($event);
        $event_string =~ s/<a name=\"(.*?)\">/<a href=\"\/logserver\/display\?channel=$channel_name&year=$year&month=$month&day=$day\#$1\">/;
        $response .= $event_string . "\n";
      }

      return $self->std_response($response);
    }                       
  }          
}

sub event_as_html_string {
  my $self = shift;
  my $event = shift;

  my $type = $event->type;

  my $format_string = '<a name="%timestamp"></a><span class="time">%hour:%min:%sec</span><span class="irctext"> ';

  if($type eq 'public') {
    $format_string .= '<span class="public">&lt;%nick&gt; %text</span>';
  } elsif($type eq 'caction') {
    $format_string .= '<span class="caction">* %nick %text</span>';
  } elsif($type eq 'mode') {
    $format_string .= '<span class="mode">%nick set mode: %text</span>';
  } elsif($type eq 'topic') {
    $format_string .= '<span class="topic">[%type] %nick: %text</span>';
  } elsif($type eq 'nick') {
    $format_string .= '<span class="nick">[%type] %nick changed nick to: %nick</span>';
  } elsif($type eq 'quit') {
    $format_string .= '<span class="quit">[%type] %nick quit: %text</span>';
  } elsif($type eq 'kick') {
    $format_string .= '<span class="kick">[%type] %target was kicked by %nick (%text)</span>';
  } elsif($type eq 'join') {
    $format_string .= '<span class="join">%nick (%userhost) joined %channel</span>';
  } elsif($type eq 'part') {
    $format_string .= '<span class="part">%nick (%userhost) left %channel</span>';
  }

  $format_string .= '</span><br>';

  my $result =
      $event->as_string_formatted($format_string,
                                  [ 'html',
                                    sub {
                                      s#(\w+://.*?|www\d*\..*?|ftp\d*\..*?|web\d*\..*?)(\s+|'|,|$)#<a href="$1">$1</a>$2#g;
                                    }
                                    ]);
  
  return $result;
}

sub std_response {
  my $self = shift;
  my $html = shift;

  return ('text/html', $html . '</body></html>', $self->config->get('authtyperequired'));
}

1;


