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

use Date::Manip;

use CGI qw(:standard);

our $VERSION = '0.1.0';

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

  $response .= '</head><body><center><h1>Perlbot Logs</h1></center><hr>';
        
  my ($command, $options_string) = $arguments =~ /^(.*?)\?(.*)$/;

  my $options;

  foreach my $option (split('&', $options_string)) {
    my ($key, $value) = $option =~ /^(.*?)=(.*)$/;
    $options->{$key} = $value;
  }

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

    # standard header
    $response .= "<a href=\"/logserver/search?channel=" . $options->{channel} . "\">[search]</a> <a href=\"/logserver/display?channel=" . $options->{channel} . "\">[" . $options->{channel} . "]</a> <a href=\"/logserver\">[top]</a><p>";

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

      $response .= "<center><h1>Logs for channel: " . $options->{channel} . "</h1></center>";
      $response .= '<p><hr>';
      
      $response .= "<p><center><h1>$year</h1></center>\n";
      $response .= "<table width=\"100%\" border=\"0\">\n  <tr valign=\"center\" align=\"center\">\n";

      foreach my $month ((1..12)) {
        $response .= "    <td width=\"25%\" valign=\"center\" align=\"center\">\n";
        $month = sprintf("%02d", $month);
        my $cal = HTML::CalendarMonth->new(year => $year, month => $month);
        foreach my $day ($cal->days()) {
          if($channel->logs->search({ initialdate => Date::Manip::UnixDate("$year/$month/$day-00:00:00",'%s'),
                                      finaldate   => Date::Manip::UnixDate("$year/$month/$day-23:59:59",'%s'),
                                      boolean     => 1 })) {
            $cal->item($day)->wrap_content(HTML::Element->new('a', href => "/logserver/display?channel=" . $options->{channel} . "&year=${year}&month=${month}&day=${day}"));
          }
        }
        $response .= $cal->as_HTML();
        $response .= "</td>\n";
        if($month % 4 == 0) { $response .="  </tr>\n  <tr>\n"; }
      }
      $response .= "</table>\n";

      return $self->std_response($response);
    }

    if(defined($options->{day}) && defined($options->{month}) && defined($options->{year})) {
      my @events = $channel->logs->search({ initialdate => Date::Manip::UnixDate($options->{year} . "/" . $options->{month} . "/" . $options->{day} . "-00:00:00",'%s'),
                                              finaldate   => Date::Manip::UnixDate($options->{year} . "/" . $options->{month} . "/" . $options->{day} . "23:59:59",'%s')});

      my @loglines;
      while(my $event = shift @events) {
        push(@loglines, $event->as_string());
      }

      foreach (@loglines) {
        s/\&/\&amp\;/g;
        s/</\&lt\;/g;
        s/>/\&gt\;/g;
        s/(\&lt\;.*?\&gt\;)/<b>$1<\/b>/;
        s|^(\d+/\d+/\d+-\d+:\d+:\d+) \* (\w+) (.*)|$1 * <b>$2</b> $3|;
        s|^(\d+/\d+/\d+-\d+:\d+:\d+\s)(.*? joined \#.*?$)|$1<font color=\"blue\">$2</font>|;
        s|^(\d+/\d+/\d+-\d+:\d+:\d+\s)(.*? left \#.*?$)|$1<font color=\"blue\">$2</font>|;
        s|^(\d+/\d+/\d+-\d+:\d+:\d+\s)(\[.*?\])|$1<font color=\"red\">$2</font>|;
        s|(\d+/\d+/\d+-\d+\:\d+:\d+)|<a name=\"$1\">$1</a>|;
        s#(\w+://.*?|www\d*\..*?|ftp\d*\..*?|web\d*\..*?)(\s+|'|,|$)#<a href="$1">$1</a>$2#;
        $response .= "<tt>$_</tt><br>";
      }
      
      return $self->std_response($response);
    }

  }
  
  if($command && $command eq 'search') {
    
    if(!$options->{channel}) {
      return $self->std_response($response . "<b>You must specify a channel!</b>");
    }

    my $channel = $self->perlbot->get_channel($options->{channel});

    $response .= "<a href=\"/logserver/search?channel=" . $options->{channel} ."\">[search]</a> <a href=\"/logserver/display?channel=" . $options->{channel} . "\">[" . $options->{channel} . "]</a> <a href=\"/logserver\">[top]</a><p>";

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

      return $self->std_response($response);
      
    } else {
      
      my @terms = split(/\+/, $options->{terms});

      my $initialyear = $options->{initialyear};
      my $initialmonth = $options->{initialmonth};
      my $initialday = $options->{initialday};
      my $initialhour = $options->{initialhour} || 0;
      my $initialmin = $options->{initialmin} || 0;
      my $initialsec = $options->{initialsec} || 0;
      my $initialdatestring = sprintf("%04d/%02d/%02d-%02d:%02d:%02d",
                                      $initialyear,
                                      $initialmonth,
                                      $initialday,
                                      $initialhour,
                                      $initialmin,
                                      $initialsec);

      my $finalyear = $options->{finalyear};
      my $finalmonth = $options->{finalmonth};
      my $finalday = $options->{finalday};
      my $finalhour = $options->{finalhour} || 23;
      my $finalmin = $options->{finalmin} || 59;
      my $finalsec = $options->{finalsec} || 59;
      my $finaldatestring = sprintf("%04d/%02d/%02d-%02d:%02d:%02d",
                                      $finalyear,
                                      $finalmonth,
                                      $finalday,
                                      $finalhour,
                                      $finalmin,
                                      $finalsec);

      my $initialdate = Date::Manip::UnixDate($initialdatestring,'%s');
      my $finaldate = Date::Manip::UnixDate($finaldatestring,'%s');

      my $nick = $options->{nick};
      my $type = $options->{type}; if($type eq 'all') { $type = undef; };

      my @events = $channel->logs->search({ terms => \@terms,
                                            initialdate => $initialdate,
                                            finaldate => $finaldate,
                                            nick => $nick,
                                            type => $type });

      my @loglines;
      while(my $event = shift @events) {
        push(@loglines, $event->as_string());
      }
      
      foreach (@loglines) {
        s/\&/\&amp\;/g;
        s/</\&lt\;/g;
        s/>/\&gt\;/g;
        s/(\&lt\;.*?\&gt\;)/<b>$1<\/b>/;
        s|^(\d+/\d+/\d+-\d+:\d+:\d+) \* (\w+) (.*)|$1 * <b>$2</b> $3|;
        s|^(\d+/\d+/\d+-\d+:\d+:\d+\s)(.*? joined \#.*?$)|$1<font color=\"blue\">$2</font>|;
        s|^(\d+/\d+/\d+-\d+:\d+:\d+\s)(.*? left \#.*?$)|$1<font color=\"blue\">$2</font>|;
        s|^(\d+/\d+/\d+-\d+:\d+:\d+\s)(\[.*?\])|$1<font color=\"red\">$2</font>|;
        s|(\d+/\d+/\d+-\d+\:\d+:\d+)|<a name=\"$1\">$1</a>|;
        s#(\w+://.*?|www\d*\..*?|ftp\d*\..*?|web\d*\..*?)(\s+|'|,|$)#<a href="$1">$1</a>$2#;
        $response .= "<tt>$_</tt><br>";
      }

      return $self->std_response($response);
    }                       
  }          

=pod
  if($chan && !$year && !$search) {
    $response .= "<a href=\"/logs/${chan}/search\">[search]</a> <a href=\"/logs/${chan}\">[${chan}]</a> <a href=\"/logs\">[top]</a><p>";
    if(!opendir(LOGLIST, File::Spec->catfile($self->logdir, $chan))) {
      $response .= "No logs for channel: $chan";
    } else {
      my @tmpfiles =  readdir(LOGLIST);
      my @logfiles = sort(@tmpfiles);
      close LOGLIST;
      
      my @years;
      
      foreach my $logfile (@logfiles) {
        if (!($logfile =~ /^\.\.?$/)) {
          my ($tmpyear) = $logfile =~ /^(\d+)\./;
          
          if(!grep { /$tmpyear/ } @years) { push(@years, $tmpyear); }
        }
      }
      
      $response .= "<p><h2>Logs for $chan in:</h2>";
      $response .= '<p><hr><p><ul>';
      foreach my $year (@years) {
        $response .= "<li><b><a href=\"/logs/${chan}/${year}\">$year</a></b>";
      }
      $response .= '</ul>';
    }
  }
  
  if($chan && $year && !$month && !$search) {
    $response .= "<a href=\"/logs/${chan}/search\">[search]</a> <a href=\"/logs/${chan}\">[${chan}]</a> <a href=\"/logs\">[top]</a><p>";
    
    use HTML::CalendarMonth;
    
    if(!opendir(LOGLIST, File::Spec->catfile($self->logdir, $chan))) {
      $response .= "No logs for channel: $chan";
    } else {
      my @tmpfiles =  readdir(LOGLIST);
      my @logfiles = sort(@tmpfiles);
      close LOGLIST;
      
      $response .= "<center><h1>Logs for channel: $chan</h1></center>";
      $response .= '<p><hr>';
      
      $response .= "<p><center><h1>$year</h1></center>\n";
      $response .= "<table width=\"100%\" border=\"0\">\n  <tr valign=\"center\" align=\"center\">\n";
      foreach my $month ((1..12)) {
        $response .= "    <td width=\"25%\" valign=\"center\" align=\"center\">\n";
        $month = sprintf("%02d", $month);
        my $cal = HTML::CalendarMonth->new(year => $year, month => $month);
        foreach my $day ((1..31)) {
          my $paddedday = sprintf("%02d", $day);
          my $filename = "$year.$month.$paddedday"; 
          if(grep { /\Q$filename\E/ } @logfiles) {
            $cal->item($day)->wrap_content(HTML::Element->new('a', href => "/logs/${chan}/${year}/${month}/${paddedday}"));
          }
        }
        $response .= $cal->as_HTML();
        $response .= "</td>\n";
        if($month % 4 == 0) { $response .="  </tr>\n  <tr>\n"; }
      }
      $response .= "</table>\n";
    }
  }
  
  if($chan && $year && $month && !$day && !$search) {
    $response .= "<a href=\"/logs/${chan}/search\">[search]</a> <a href=\"/logs/${chan}\">[${chan}]</a> <a href=\"/logs\">[top]</a><p>";
    use HTML::CalendarMonth;
    
    if(!opendir(LOGLIST, File::Spec->catfile($self->logdir, $chan))) {
      $response .= "No logs for channel: $chan";
    } else {
      my @tmpfiles =  readdir(LOGLIST);
      my @logfiles = sort(@tmpfiles);
      close LOGLIST;
      
      $response .= "<center><h1>Logs for channel: $chan</h1></center>";
      $response .= '<p><hr>';
      
      $response .= "<p><center><h1>$year</h1></center>\n";
      $month = sprintf("%02d", $month);
      my $cal = HTML::CalendarMonth->new(year => $year, month => $month);
      foreach my $day ((1..31)) {
        my $paddedday = sprintf("%02d", $day);
        my $filename = "$year.$month.$paddedday";
        if(grep { /\Q$filename\E/ } @logfiles) {
          $cal->item($day)->wrap_content(HTML::Element->new('a', href => "/logs/${chan}/${year}/${month}/${paddedday}"));
        }
      }
      $response .= $cal->as_HTML();
    }
  }
  
  if($chan && $year && $month && $day && !$search) {
    $response .= "<a href=\"/logs/${chan}/search\">[search]</a> <a href=\"/logs/${chan}\">[${chan}]</a> <a href=\"/logs\">[top]</a><p>";
    my $filename = File::Spec->catfile($self->logdir, $chan, "$year.$month.$day");
    
    if(open(FILE, $filename)) {
      my @lines = <FILE>;
      close(FILE);
      
      foreach (@lines) {
        s/\&/\&amp\;/g;
        s/</\&lt\;/g;
        s/>/\&gt\;/g;
        s/(\&lt\;.*?\&gt\;)/<b>$1<\/b>/;
        s|^(\d+:\d+:\d+) \* (\w+) (.*)|$1 * <b>$2</b> $3|;
        s|^(\d+:\d+:\d+\s)(.*? joined \#.*?$)|$1<font color=\"blue\">$2</font>|;
        s|^(\d+:\d+:\d+\s)(.*? left \#.*?$)|$1<font color=\"blue\">$2</font>|;
        s|^(\d+:\d+:\d+\s)(\[.*?\])|$1<font color=\"red\">$2</font>|;
        s|(\d+\:\d+:\d+)|<a name=\"$1\">$1</a>|;
        s#(\w+://.*?|www\d*\..*?|ftp\d*\..*?|web\d*\..*?)(\s+|'|,|$)#<a href="$1">$1</a>$2#;
        $response .= "<tt>$_</tt><br>";
      }
    }
  }                               
  
  if($search) {
    if(!scalar @searchwords) {
      $response .= "<a href=\"/logs/${chan}/search\">[search]</a> <a href=\"/logs/${chan}\">[${chan}]</a> <a href=\"/logs\">[top]</a><p>";
      $response .= "<h2>Search logs for channel: $chan</h2><p>";
      $response .= "<form method=\"get\" action=\"/logs/${chan}/search\">";
      $response .= "Enter words to search for: <input type=\"text\" name=\"words\"  />";
      $response .= "<input type=\"submit\" name=\".submit\" />";
      $response .= "</form>";
    } else {
      $response .= "<a href=\"/logs/${chan}/search\">[search]</a> <a href=\"/logs/${chan}\">[${chan}]</a> <a href=\"/logs\">[top]</a><p>";
      
      if(opendir(DIR, File::Spec->catfile($self->logdir, $chan))) {
        my @tmp = readdir(DIR);
        my @files = sort(@tmp);
        
        my $results_found = 0;
        
        foreach my $file (@files) {
          open(FILE, File::Spec->catfile($self->logdir, $chan, $file));
          my @lines = <FILE>;
          close FILE;
          
          foreach my $word (@searchwords) {
            @lines = grep(/\Q$word\E/i, @lines);  
          }
          
          foreach (@lines) {
            s/</&lt;/g;
            s/>/&gt;/g;
          }
          
          if (@lines) {
            $results_found = 1;
            ($year, $month, $day) = split(/\./, $file);
            $response .= "<p><b><a href=\"/logs/${chan}/${year}/${month}/${day}\">$file</a></b>";
            $response .= "<p>";
            foreach (@lines) {
              s/</\&lt\;/g;
              s/>/\&gt\;/g;
              s/(\&lt\;.*?\&gt\;)/<b>$1<\/b>/;
              s|^(\d+:\d+:\d+) \* (\w+) (.*)|$1 * <b>$2</b> $3|;
              s|^(\d+:\d+:\d+\s)(.*? joined \#.*?$)|$1<font color=\"blue\">$2</font>|;
              s|^(\d+:\d+:\d+\s)(.*? left \#.*?$)|$1<font color=\"blue\">$2</font>|;
              s|^(\d+:\d+:\d+\s)(\[.*?\])|$1<font color="red">$2</font>|;
              s|(\d+:\d+:\d+)|<a href="/logs/${chan}/${year}/${month}/${day}#$1">$1</a>|;
              s#(\w+://.*?|www\d*\..*?|ftp\d*\..*?|web\d*\..*?)(\s+|'|,|$)#<a href="$1">$1</a>$2#;
              $response .= "<tt>$_</tt><br>";
              
            }
          }
        }
        
        if(!$results_found) {
          $response .= '<center><h2>No results found for: ' . join(' ', @searchwords) . '</h2></center>';
        }
        
        closedir(DIR);
      }
    }
  }

=cut

  $response .= '</body></html>';

  return $self->std_response($response);
}

sub std_response {
  my $self = shift;
  my $html = shift;

  return ('text/html', $html . '</body></html>', $self->config->get('authtyperequired'));
}

1;


