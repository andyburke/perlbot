package Perlbot::Plugin::LogSearch;

use strict;

use Perlbot::Plugin;
use Perlbot::Logs;
use base qw(Perlbot::Plugin);

use Time::Local;

sub init {
  my $self = shift;

  $self->want_public(0);

  $self->hook('logsearch', \&logsearch);
}

sub logsearch {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($channel, $maxresults, $initialdate, $finaldate, $terms) = $text =~ /(#?\w+)?\s+?(\d+)?\s+?(\d\d\d\d[\/\.]\d\d[\/\.]\d\d)?\s+?(\d\d\d\d[\/\.]\d\d[\/\.]\d\d)?\s+?(.*)/;

  print "channel: $channel\n";
  print "maxresults: $maxresults\n";
  print "initialdate: $initialdate\n";
  print "finaldate: $finaldate\n";
  print "terms: $terms\n";

  my @terms = ('ender', 'blah');
  use Data::Dumper;
  print Dumper $self->perlbot->logs->search('perlbot', \@terms, timelocal(39,32,18,21,0,2003), timelocal(41,32,18,21,0,2003));
 
#      my($channel) = split(/ /, $args);
#      $args =~ s/^$channel\s+//;
#
#      my ($tempmaxresults) = $args =~ /^(\d+)\s+/;
#      if($tempmaxresults) { $maxresults = $tempmaxresults; }
#      $args =~ s/^\d+\s+//;
#
#      my ($initialyear, $initialmonth, $initialday) = $args =~ /(\d\d\d\d)[\.\/-](\d\d)[\.\/-](\d\d)/;
#      $args =~ s/\d\d\d\d[\.\/-]\d\d[\.\/-]\d\d\s*//;
#      $initialdate = $initialyear . $initialmonth . $initialday;
#
#      my ($finalyear, $finalmonth, $finalday) = $args =~ /(\d\d\d\d)[\.\/-](\d\d)[\.\/-](\d\d)/;
#      $args =~ s/\d\d\d\d[\.\/-]\d\d[\.\/-]\d\d\s*//;
#      $finaldate = $finalyear . $finalmonth . $finalday;
#
#      my @words = split(/ /, $args);
#     
#      if(!@words) {
#        $conn->privmsg($who, "usage: ${pluginprefix}logsearch <channel> [<maxresults>] [<initialdate> [<finaldate>]] <terms>");
#        $conn->{_connected} = 0;
#        exit 0;
#      }
#
#      if(!$channel) {
#	$conn->privmsg($who, "usage: ${pluginprefix}logsearch <channel> [<maxresults>] [<initialdate> [<finaldate>]] <terms>");
#	$conn->{_connected} = 0;
#	exit 0;
#      }
#      
#      if($Logs::basedir =~ /^\./) {
#        my @topleveldir = `pwd`;
#        chomp $topleveldir[0];
#        $logdir = $topleveldir[0] . "/" . $Logs::basedir . "/" . $channel . "/";
#      } else {
#        $logdir = $Logs::basedir . "/" . $channel . "/";
#      }
#     
#      if($Logs::basedir =~ /^\./) {
#	my @topleveldir = `pwd`;
#	chomp $topleveldir[0];
#      }
#
#      if(opendir(DIR, $logdir)) {
#	my @tmpfiles = readdir(DIR);
#	close DIR;
#	
#	my @files = sort(@tmpfiles);
#	foreach my $file (@files) {
#          my ($year) = $file =~ /^(\d\d\d\d)/;
#          my ($month) = $file =~ /\.(\d\d)\./;
#          my ($day) = $file =~ /(\d\d)$/;
#          my $abstime = $year . $month . $day; # YYYYMMDD
#
#          if($initialdate) {
#            if($abstime < $initialdate) { next; }
#          }
#          if($finaldate) {
#            if($abstime > $finaldate) { next; }
#          }
#
#	  my @lines;
#	  open FILE, "$logdir$file";
#	  @lines = <FILE>;
#	  close FILE;
#	  
#	  foreach my $word (@words) {
#	    @lines = grep(/\Q$word\E/i, @lines);        
#	  }
#	  
#	  my $i = 0;
#	  foreach(@lines) {
#	    if($results < $maxresults) {
#	      if($i == 0) { $conn->privmsg($who, "$file:"); }
#	      chomp $lines[$i];
#	      $conn->privmsg($who, "  " . $lines[$i]);
#	      $results++;
#	      $i++;
#	    } else {
#	      $conn->{_connected} = 0;
#	      exit 0;
#	    }
#	  }
#	}
#	
#      } else {
#	$conn->privmsg($who, "usage: ${pluginprefix}logsearch <channel> [<maxresults>] [<initialdate> [<finaldate>]] <terms>");
#	$conn->{_connected} = 0;
#	exit 0;
#      }
#      
#      $conn->{_connected} = 0;
#      exit 0;
#    }
#  }

}

1;
