#!/usr/bin/perl

#a perl script to search through irc logfiles
#and display occurences of specific words

package LogSearch::Plugin;

use Perlbot;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my $conn = shift;
  my $event = shift;
  my $who = $event->{to}[0];

  logsearch($conn, $event, $who);
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $who = $event->nick;

  logsearch($conn, $event, $who);
}
 
sub logsearch {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $args = $event->{args}[0];
  my $logdir;
    
  my $maxresults = 5;
  my $results = 0;
    
  my $initialdate;
  my $finaldate;
    
  my $pid;

  if($args =~ /^${pluginprefix}logsearch/) { 
    if(!defined($pid = fork)) {
      $conn->privmsg($who, "error in logsearch plugin: failed to fork");
      return;
    } 
    
    if($pid) {
      #parent
      
      $SIG{CHLD} = sub { wait; };
      return;
      
    } else {
      # child
      $args =~ tr/[A-Z]/[a-z]/;
      
      $args =~ s/^${pluginprefix}logsearch\s+//;

      my($channel) = split(/ /, $args);
      $args =~ s/^$channel\s+//;

      my ($tempmaxresults) = $args =~ /^(\d+)\s+/;
      if($tempmaxresults) { $maxresults = $tempmaxresults; }
      $args =~ s/^\d+\s+//;

      my ($initialyear, $initialmonth, $initialday) = $args =~ /(\d\d\d\d)[\.\/-](\d\d)[\.\/-](\d\d)/;
      $args =~ s/\d\d\d\d[\.\/-]\d\d[\.\/-]\d\d\s*//;
      $initialdate = $initialyear . $initialmonth . $initialday;

      my ($finalyear, $finalmonth, $finalday) = $args =~ /(\d\d\d\d)[\.\/-](\d\d)[\.\/-](\d\d)/;
      $args =~ s/\d\d\d\d[\.\/-]\d\d[\.\/-]\d\d\s*//;
      $finaldate = $finalyear . $finalmonth . $finalday;

      my @words = split(/ /, $args);
     
      if(!@words) {
        $conn->privmsg($who, "usage: ${pluginprefix}logsearch <channel> [<maxresults>] [<initialdate> [<finaldate>]] <terms>");
        $conn->{_connected} = 0;
        exit 0;
      }

      if(!$channel) {
	$conn->privmsg($who, "usage: ${pluginprefix}logsearch <channel> [<maxresults>] [<initialdate> [<finaldate>]] <terms>");
	$conn->{_connected} = 0;
	exit 0;
      }
      
      if($Logs::basedir =~ /^\./) {
        my @topleveldir = `pwd`;
        chomp $topleveldir[0];
        $logdir = $topleveldir[0] . "/" . $Logs::basedir . "/" . $channel . "/";
      } else {
        $logdir = $Logs::basedir . "/" . $channel . "/";
      }
     
      if($Logs::basedir =~ /^\./) {
	my @topleveldir = `pwd`;
	chomp $topleveldir[0];
      }

      if(opendir(DIR, $logdir)) {
	my @tmpfiles = readdir(DIR);
	close DIR;
	
	my @files = sort(@tmpfiles);
	foreach my $file (@files) {
          my ($year) = $file =~ /^(\d\d\d\d)/;
          my ($month) = $file =~ /\.(\d\d)\./;
          my ($day) = $file =~ /(\d\d)$/;
          my $abstime = $year . $month . $day; # YYYYMMDD

          if($initialdate) {
            if($abstime < $initialdate) { next; }
          }
          if($finaldate) {
            if($abstime > $finaldate) { next; }
          }

	  my @lines;
	  open FILE, "$logdir$file";
	  @lines = <FILE>;
	  close FILE;
	  
	  foreach my $word (@words) {
	    @lines = grep(/\Q$word\E/i, @lines);        
	  }
	  
	  my $i = 0;
	  foreach(@lines) {
	    if($results < $maxresults) {
	      if($i == 0) { $conn->privmsg($who, "$file:"); }
	      chomp $lines[$i];
	      $conn->privmsg($who, "  " . $lines[$i]);
	      $results++;
	      $i++;
	    } else {
	      $conn->{_connected} = 0;
	      exit 0;
	    }
	  }
	}
	
      } else {
	$conn->privmsg($who, "usage: ${pluginprefix}logsearch <channel> [<maxresults>] [<initialdate> [<finaldate>]] <terms>");
	$conn->{_connected} = 0;
	exit 0;
      }
      
      $conn->{_connected} = 0;
      exit 0;
    }
  }

}

1;
