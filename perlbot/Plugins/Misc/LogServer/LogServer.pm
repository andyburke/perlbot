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

our $VERSION = '0.0.3';

sub init {
  my $self = shift;

  $self->want_msg(0);
  $self->want_public(0);
  
  $self->hook_web('logs', \&logs, 'Channel Logs');
}

sub logdir {
  my $self = shift;

  return Perlbot::LogFile::directory_from_config($self->perlbot->config);
}

sub logs {
  my $self = shift;
  my @args = @_;

  my $response = '<html><head><title>Perlbot Logs</title>';
 
  if (lc($self->config->get('allowsearchengines')) eq 'yes') {
     # don't bother adding the meta tag to disallow archiving
  } else {
    $response .= '<meta name="ROBOTS" content="NOINDEX, NOFOLLOW, NOARCHIVE" />';
  }

  $response .= '</head><body><center><h1>Perlbot Logs</h1></center><hr>';

  my ($chan, $year, $month, $day) = @args;
  my $search;
  my @searchwords;

  if(defined($year) && $year =~ /search/) {
    $year =~ s/^search//i;
    $year =~ s/\?//;
    $year =~ s/words=//;

    @searchwords = split(/\+/, $year);

    $year = undef;
    $search = 1;
  }          
          
  if(!$chan && !$search) {
    if(opendir(DIR, $self->logdir)) {
      my @channels = readdir(DIR);
      closedir(DIR);
      
      $response .= '<ul>';
      foreach my $channel (@channels) {
        if (-d File::Spec->catfile($self->logdir, $channel)) {
          if ($channel !~ /^(\.\.?|msg)$/) {
            $response .= "<li><b><a href=\"/logs/${channel}\">$channel</a></b>";
          }
        }
      }
      $response .= '</ul>';
    } else {
      $response .= 'Could not open the bot\'s logdir!';
    }
  }
  
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

  $response .= '</body></html>';

  return ('text/html', $response, $self->config->get('authtyperequired'));
}

1;


