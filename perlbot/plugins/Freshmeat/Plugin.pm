# Andrew Burke <burke@pas.rochester.edu>
#
# This gets the latest Freshmeat entries.

package Freshmeat::Plugin;

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

  if($args =~ /^!freshmeat\s*/  || $args =~ /^!fm\s*/) {
    if($args =~ /^!freshmeat\s+search.*/ || $args =~/^!fm\s+search.*/) {
      get_fm_search($conn, $event, $event->{to}[0]);
    } else {
      get_fm($conn, $event, $event->{to}[0]);
    } 
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^!freshmeat\s*/  || $args =~ /^!fm\s*/) {
    if($args =~ /^!freshmeat\s+search.*/ || $args =~/^!fm\s+search.*/) {
      get_fm_search($conn, $event, $event->nick);
    } else {
      get_fm($conn, $event, $event->nick);
    } 
  }
}

sub get_fm {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $max;

  ($max = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
  $max =~ s/^!freshmeat\s*//;
  $max =~ s/^!fm\s*//;
  $max =~ s/\s+(\d+)\s*.*/\1/;

  if($max eq '') { $max = 5; }

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in freshmeat plugin...");
    return;
  }

  if($pid) {
    #parent
    
    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my($remote,$port,$iaddr,$paddr,$proto,$line);
    $remote = "freshmeat.net";
    $port = "80";
    
    if(!defined($iaddr = inet_aton($remote))) {
      $conn->privmsg($who, "Could not get address for $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($paddr = sockaddr_in($port, $iaddr))) {
      $conn->privmsg($who, "Could not get port for $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($proto = getprotobyname('tcp'))) {
      $conn->privmsg($who, "Could not get tcp protocol");
      $conn->{_connected} = 0;
      exit 1;
    }
    
    if(!socket(SOCK, PF_INET, SOCK_STREAM, $proto)) {
      $conn->privmsg($who, "Could not open socket to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!connect(SOCK, $paddr)) {
      $conn->privmsg($who, "Could not connect to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    $msg = "GET /\n\n";

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($who, "Could not send to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    my $headline = '';
    my $author = '';
    my $date = '';
    my $formatteddate = '';

    my $i = 1;
    while (my $lala = <SOCK>) {

      if($headline eq '') {
	($headline) = $lala =~ /.*?<B><FONT.*?>(.*?)<\/FONT><\/B>.*?/;
      }
      if($author eq '') {
	($author) = $lala =~ /<SMALL><B><A HREF=.*?>(.*?)<\/A>/;
      }
      if($date eq '') {
	($date) = $lala =~ /<SMALL>.*?<\/A> - (.*?)<\/B><\/SMALL>/;
	my ($year) = $date =~ /.*?(\d\d\d\d).*?/;
	my ($month) = $date =~ /.*?(January|February|March|April|May|June|July|August|September|October|November|December).*?/;
	my ($day) = $date =~ /.*?(\d+)[th|st]/;
	my ($time) = $date =~ /,\s*(\d+:\d+).*?/;

	$month =~ s/January/01/;
	$month =~ s/Februaury/02/;
	$month =~ s/March/03/;
	$month =~ s/April/04/;
	$month =~ s/May/05/;
	$month =~ s/June/06/;
	$month =~ s/July/07/;
	$month =~ s/August/08/;
	$month =~ s/September/09/;
	$month =~ s/October/10/;
	$month =~ s/November/11/;
	$month =~ s/December/12/;
	
	$formatteddate = "$year/$month/$day $time";
      }

      my $header_printed = 0;
      
      if(($headline ne '') && ($author ne '') && ($date ne '')) {
	unless($header_printed) {
	  $conn->privmsg($who, "Freshmeat Headlines:");
	  $header_printed = 1;
	}

	if($i > $max) { last; }
	my $short_title = substr($headline, 0, 31);
	my $short_author = substr($author, 0, 10);
	my $output = sprintf("%32s / %10s / %16s\n", $short_title, $short_author, $formatteddate);
	$conn->privmsg($who, $output);

	$headline = '';
	$author = '';
	$date = '';
	$formatteddate = '';

	$i++;
	next;
      }
    }

    close SOCK;
    $conn->{_connected} = 0;
    exit 0;
  }

  close SOCK;
  
}

sub get_fm_search {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $args;
  my $max;

  $args = $event->{args}[0];

  my($term, $max) = split(':', $args, 2);

  $term =~ s/^!freshmeat\s+search\s*//;
  $term =~ s/^!fm\s+search\s*//;
  $term =~ s/\s+/+/g;


  $max =~ s/.*:\s*(\d+).*/\1/;

  if($max eq '' || $max < 1) { $max = 3; }

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in freshmeat plugin...");
    return;
  }

  if($pid) {
    #parent
    
    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my($remote,$port,$iaddr,$paddr,$proto,$line);
    $remote = "core.freshmeat.net";
    $port = "80";
    
    if(!defined($iaddr = inet_aton($remote))) {
      $conn->privmsg($who, "Could not get address for $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($paddr = sockaddr_in($port, $iaddr))) {
      $conn->privmsg($who, "Could not get port for $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($proto = getprotobyname('tcp'))) {
      $conn->privmsg($who, "Could not get tcp protocol");
      $conn->{_connected} = 0;
      exit 1;
    }
    
    if(!socket(SOCK, PF_INET, SOCK_STREAM, $proto)) {
      $conn->privmsg($who, "Could not open socket to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!connect(SOCK, $paddr)) {
      $conn->privmsg($who, "Could not connect to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    $msg = "GET /search.php3?query=$term\n\n";

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($who, "Could not send to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    my $appindex_entry = '';
    my $score = '';
    my $link = '';

    my $i = 1;
    while (my $lala = <SOCK>) {

      if($lala =~ /No records have been found/) {
	$conn->privmsg($who, "No records found for: $term");
	$conn->{_connected} = 0;
	exit 0;
      }

      if($score eq '') {
	($score) = $lala =~ /<TR BGCOLOR\=\"\#FFFFFF\"><TD NOWRAP VALIGN.*?score:\s+(.*?)<\/SMALL><\/TD>.*/;
      }
      if($link eq '') {
	($link) = $lala =~ /<TR BGCOLOR\=\"\#FFFFFF\"><TD NOWRAP VALIGN.*?<FONT FACE.*?HREF.*?\"(.*?)\">.*/;
      }
      if($appindex_entry eq '') {
	($appindex_entry) = $lala =~ /<TR BGCOLOR\=\"\#FFFFFF\"><TD NOWRAP VALIGN.*?<FONT FACE.*?HREF=.*?>(.*?)<\/A>.*/;
      }
      
      if(($appindex_entry ne '') && ($score ne '') && ($link ne '')) {
	if($i > $max) { last; }
	$conn->privmsg($who, "$appindex_entry / score: $score");
	$conn->privmsg($who, "  $link");
	
	$appindex_entry = '';
	$score = '';
	$link = '';
	
	$i++;
	next;
      }
    }

    close SOCK;
    $conn->{_connected} = 0;
    exit 0;
  }

  close SOCK;
  
}



1;







