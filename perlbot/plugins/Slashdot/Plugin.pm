# this was originally a stand-alone script... all the original
# info follows after this.  I ported it to a perlbot plugin:
# !slasdot will return the news from slashdot, ie:
#
#<ender_> !slashdot
#<perldev> Slashdot last updated on: August 20 16:32:47
#<perldev>  NASA test fires hybrid rocket m /      Hemos / 16:32:47
#<perldev>      Interview: Mandrake Answers /    Roblimo / 16:00:16
#<perldev>               ENIAC Story on NPR /      Hemos / 15:41:44
#
# many thanks to the original author.
#
#
#  File: get_slashdot_news
#                   Mister House Slashdot
#  Slashdot back end for MisterHouse (or not).  Checks Slashdot for news
#  and prints (or speaks) the result.
#
#  Author:
#        David Dellanave ddn@hps.com
#  Version: 
#        1.0
#
#  Last update:
#        8/5/99
#
#  Changes:
#         - Added a feature where the program can create a "database" in the /tmp directory for
#           other instances of get_slashdot to read from.  The idea was to have it be able to 
#           as a login prorgram, without always having to go out to the net to get it.
#
#
#  Notes:
#       Please let me know if anything doesnt work for you.  Also let me know 
#       of any <HTML> snippets I dont catch.  Good notes are always welcome, 
#       I like e-mail :) Bottom line: Have fun with it /. 
#
#  This free software is licensed under the terms of the 
#  GNU public license.
#  Copyleft 1999 David Dellanave

package Slashdot::Plugin;

use IO::Socket;
use IO::Handle;

use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my $conn = shift;
  my $event = shift;
  my $args;

  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^${pluginchar}slashdot\s*/) {
      if($args =~ /\s+search/){
	  get_ss($conn, $event, $event->{to}[0]);
      }else{
	  get_slashdot($conn, $event, $event->{to}[0]);
      }
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;

  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^${pluginchar}slashdot\s*/) {
    if($args =~ /\s+search/){
      get_ss($conn, $event, $event->nick);
    }else{
      get_slashdot($conn, $event, $event->nick);
    }
  }
}

sub get_slashdot {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $max;

  ($max = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
  $max =~ s/^${pluginchar}slashdot\s*//;
  $max =~ s/\s+(\d+)\s*.*/\1/;

  if($max eq '') { $max = 5; }

# You can tell the script to use a proxy. If $PROXY is empty it
# will not use one. By default the script takes the value of the
# http_proxy environment variable by default. So if there isn't 
# one no proxy will be used.

  my $PROXY = "";
  my $PROXYPORT = 0;
  if($ENV{http_proxy}) {
    $ENV{http_proxy} =~ m$http://(.*?):(.*?)/$;
    $PROXY = $1;
    $PROXYPORT = $2;
  }
  
# On the next line add how many hours you need to add or subtract from EDT
# to get your time.  Ie: $zone = "+5" to get GMT or -5 for whatever it is ;)
# Leave blank for EDT
  $zone = "-1";

######################### End of Configuration ############################

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in slashdot plugin...");
    return;
  } 

  if($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my($iaddr, $paddr, $port, $proto, $month, $url, @articles, $runs, $times, @time, %months, $months, $day);
  
    %months = qw(1 January 2 February 3 March 4 April 5 May 6 June 7 July 8 August 9 September 10 October 11 November 12 December);
    if($PROXY) {
      $iaddr = gethostbyname($PROXY);
      $port = $PROXYPORT;
      $url = "http://slashdot.org/slashdot.xml";
    } else 	{
      $iaddr = gethostbyname("slashdot.org");
      $port = 80;
      $url = "/slashdot.xml";
    }
    
    
    $proto = getprotobyname("tcp");
    $paddr = sockaddr_in($port, $iaddr);
    
    $runs = 0;
    if(!socket(SLASH, PF_INET, SOCK_STREAM, $proto)) {
      $conn->privmsg($who, "Socket error in slashdot plugin: $!");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!connect(SLASH, $paddr)) {
      $conn->privmsg($who, "Connection error in slashdot plugin: $!");
      $conn->{_connected} = 0;
      exit 1;
    }
    autoflush SLASH 1;
    print SLASH "GET $url\n\n";
    
    my $title = '';
    my $author = '';
    my $time = '';
    my $header_printed = 0;

    my $i = 1;
    while(my $slash = <SLASH>) {
      
      if($title eq '') {
	($title) = $slash =~ /.*?<title>(.*?)<\/title>.*?/;
      }
      if($author eq '') {
	($author) = $slash =~ /.*?<author>(.*?)<\/author>.*?/;
      }
      if($time eq '') {
	($time) = $slash =~ /.*?<time>(.*?)<\/time>.*?/;
	$time =~ s/-/\//g;
      }

      if(($title ne '') && ($author ne '') && ($time ne '')) {
	if($i > $max) { last; }
	my $short_title = substr($title, 0, 31);
	my $output = sprintf("%32s / %10s / %8s\n", $short_title, $author, $time);
	unless($header_printed) {
	  $conn->privmsg($who, "Slashdot headlines:");
	  $header_printed = 1;
	}
	$conn->privmsg($who, $output);
	$title = '';
	$author = '';
	$time = '';

	$i++;
      }
    }
    
    close SLASH;
    $conn->{_connected} = 0;
    exit 0;
  }
}

sub get_ss {
    my $conn = shift;
    my $event = shift;
    my $who = shift;
    my $HARD_max = 50;
    my $max;
    
    my $args = (split(' ', $event->{args}[0], 2))[1];
    
    my($term, $max) = split(':', $args, 2);
    
    $term =~ tr/[A-Z]/[a-z]/;
    $term =~ s/^.*?search//;
    $term =~ s/^\s*(.*?)\s*$/\1/;
    $term =~ s/\s/+/g;
    chomp $term;

    if($term eq ''){
	$conn->privmsg($who, "usage: ${pluginchar}slashdot search <keyword(s)>  : <max hits (optional)>");
	return;
    }
    
    
    $max =~ s/^\s*(\d+)\s*$/\1/;
    chomp $max;
    
    if($max eq '' || $max < 1) { $max = 3; }
    if($max > $HARD_max) { $max = $HARD_max;}
    
    if(!defined($pid = fork)) {
	$conn->privmsg($chan, "error in slashdot search plugin...");
	return;
    }
    
    if($pid) {
	#parent
	
	$SIG{CHLD} = sub { wait; };
	return;
	
    } else {
	# child
	
	my($remote,$port,$iaddr,$paddr,$proto,$line);
	$remote = "slashdot.org";
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
	
	$msg = "GET /search.pl?query=$term\n\n";
	
	if(!send(SOCK, $msg, 0)) {
	    $conn->privmsg($who, "Could not send to $remote");
	    $conn->{_connected} = 0;
	    exit 1;
	}
	
	$conn->privmsg($who, "Slashdot search results:\n ");
	my $lala = 0;
	my $count = 0;
	while ((my $input = <SOCK>) && ($count < $max)){
	    if($input =~ /No Matches Found/) {
		$conn->privmsg($who, "No matches found for: $term");
		$conn->{_connected} = 0;
		exit 0;
	    }
	    if ($input =~ /^.*?<P><\/FORM>/){
		$lala =1;
	    }
	    if ($lala == 1)	{
		if ($input =~ /.*?<\/TD>/){
		    $lala =0;
		    next;
		}
	    }
	    
	    if ($lala == 1)	{
		my $string;
		my $link;
		($string) = $input =~ /.*?><B>(.*?)<\/B>/;
		($link) = $input =~ /.*?<A href\=(.*?)>/;
		$conn->privmsg($who, " $string");
		$conn->privmsg($who, "  $link");
		$count++; 
	    }
	}
	
	$conn->{_connected} = 0;
	exit 0;
    }
}

1;















