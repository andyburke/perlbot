# Joh, Yong-iL <tolkien@nownuri.net>
#
# This gets the latest Linuxtoday entries.

package Linuxtoday::Plugin;

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

  if($args =~ /^!linuxtoday\s*/  || $args =~ /^!lt\s*/) {
    if($args =~ /^!linuxtoday\s+search.*/ || $args =~/^!lt\s+search.*/) {
      get_lt_search($conn, $event, $event->{to}[0]);
    } else {
      get_lt($conn, $event, $event->{to}[0]);
    } 
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^!linuxtoday\s*/  || $args =~ /^!lt\s*/) {
    if($args =~ /^!linuxtoday\s+search.*/ || $args =~/^!lt\s+search.*/) {
      get_lt_search($conn, $event, $event->nick);
    } else {
      get_lt($conn, $event, $event->nick);
    } 
  }
}

sub get_lt {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $max;

  ($max = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
  $max =~ s/^!linuxtoday\s*//;
  $max =~ s/^!lt\s*//;
  $max =~ s/\s+(\d+)\s*.*/\1/;

  if($max eq '') { $max = 5; }

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in linuxtoday plugin...");
    return;
  }

  if($pid) {
    #parent
    
    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my($remote,$port,$iaddr,$paddr,$proto,$line);
    $remote = "linuxtoday.com";
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

    $msg = "GET /index.html\n\n";

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($who, "Could not send to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    $conn->privmsg($who, "Today's Newswire:");

    my $headline = '';
    my $author = '';
    my $date = '';
    my $formatteddate = '';

    my $i = 1;
    while (my $lala = <SOCK>) {

      if ($lala =~ /<A HREF=\"\/story\.php3\?sn=/) {
	$lala = <SOCK>;
	($headline = $lala) =~ s/^(.*?)<\/A>.*/\1/;

	$lala = <SOCK>;

	$lala = <SOCK>;
	($date = $lala) =~ s/^<font.*?>\((.*)UTC.*/\1/;

	my ($year) = $date =~ /.*?(\d\d\d\d).*?/;
	my ($month) = $date =~ /.*?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec).*?/;
	my ($day) = $date =~ /.*?(\d+),/;
	my ($time) = $date =~ /,\s*(\d+:\d+).*?/;
	$month =~ s/Jan/1/;
	$month =~ s/Feb/2/;
	$month =~ s/Mar/3/;
	$month =~ s/Apr/4/;
	$month =~ s/May/5/;
	$month =~ s/Jun/6/;
	$month =~ s/Jul/7/;
	$month =~ s/Aug/8/;
	$month =~ s/Sep/9/;
	$month =~ s/Oct/10/;
	$month =~ s/Nov/11/;
	$month =~ s/Dec/12/;

	if($i > $max) { last; }
	my $output = sprintf("[%d/%2d/%2d %s] %s\n", $year, $month, $day, $time, $headline);
	$conn->privmsg($who, $output);
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

sub get_lt_search {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $args;
  my $max;

  $args = $event->{args}[0];

  my($term, $min, $max) = split(':', $args, 3);

  $term =~ s/^!linuxtoday\s+search\s*//;
  $term =~ s/^!lt\s+search\s*//;
  $term =~ s/\s+/+/g;


  $min =~ s/.*:\s*(\d+).*/\1/;
  $max =~ s/.*:\s*(\d+).*/\1/;

  if($min eq '' || $min < 1) { $min = 0; $max = 3; }
  elsif ($max eq '' || $max < 1) { $max = $min; $min = 0; }

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in linuxtoday plugin...");
    return;
  }

  if($pid) {
    #parent
    
    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my($remote,$port,$iaddr,$paddr,$proto,$line);
    $remote = "linuxtoday.com";
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

    $msg = "GET /search/search-action.pl?query=$term\n\n";

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($who, "Could not send to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    while (my $lala = <SOCK>) {
      if ($lala =~ /SEARCH RESULTS/) {
	last;
      }
    }
    my $i = 0;
    while (my $lala = <SOCK>) {
      if($lala =~ /there were no matches found/) {
	$conn->privmsg($who, "No records found for: $term");
	$conn->{_connected} = 0;
	exit 0;
      }

      if ($lala =~ /<br>Copyright \&copy/) {
	last;
      }
      $arr[$i] = $lala;
      $i++;
    }

    my $rslt = join(' ', @arr);
    my @lst  = split(/<BR>/, $rslt);
    $lst[0] =~ s/(\d+) stories found<P>//;
    for($i=$min; $i < $#lst && $i < $max; $i++) {
      my($link, $headline, $date) = $lst[$i] =~ /^<A HREF=\"\/story\.php3\?sn=(\d+)\">(.*)<\/A>.*<I>(.*)<\/I>.*/;
      $link = "http://linuxtoday.com/story.php3?sn=$link";

	my $short_title = substr($headline, 0, 63);
	my $output = sprintf("  %41s / %16s\n", $link, $date);
	$conn->privmsg($who, $short_title);
	$conn->privmsg($who, $output);
    }

    close SOCK;
    $conn->{_connected} = 0;
    exit 0;
  }

  close SOCK;
  
}



1;
