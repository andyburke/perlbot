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
  my $args = $event->{args}[0];
  my $logdir;
  my $who = $event->{to}[0];
  my $max_results = 5;
  my $results = 0;
  my $pid;

  if($args =~ /^!logsearch/) { 
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
    
      $args =~ s/^!logsearch\s+//;
      my @words = split(/ /, $args);
      
      my $channel = shift @words;
      
      if(!$channel) {
	$conn->privmsg($who, "No channel specified!");
	$conn->{_connected} = 0;
	exit 0;
      }
      
      if($Log::basedir =~ /^\./) {
	my @topleveldir = `pwd`;
	chomp $topleveldir[0];
	$logdir = $topleveldir[0] . "/" . $Log$
	$logdir = $topleveldir[0] . "/" . Revision 1.1  2000/07/11 03:50:05  jmuhlich
	$logdir = $topleveldir[0] . "/" . Initial revision
	$logdir = $topleveldir[0] . "/" .channel . "/";
      } else {
	$logdir = $Log$
	$logdir = Revision 1.1  2000/07/11 03:50:05  jmuhlich
	$logdir = Initial revision
	$logdir =channel . "/";
      }
      
      if(opendir(DIR, $logdir)) {
	my @tmpfiles = readdir(DIR);
	close DIR;

	my @files = sort(@tmpfiles);
	foreach my $file (@files) {
	  my @lines;
	  open FILE, "$logdir$file";
	  @lines = <FILE>;
	  close FILE;
	  
	  foreach my $word (@words) {
	    @lines = grep(/\Q$word\E/i, @lines);        
	  }
	  
	  my $i = 0;
	  foreach(@lines) {
	    if($results < $max_results) {
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
	$conn->privmsg($who, "No logs for channel: $channel");
	$conn->{_connected} = 0;
	exit 0;
      }
    }
  }
}

sub on_msg {
}

1;
