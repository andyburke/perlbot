# Andrew Burke <burke@pas.rochester.edu>
#
# This will get you the latest, lowest price from www.pricewatch.com

package PriceWatch::Plugin;

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

  if($args =~ /^!pricewatch/  || $args =~ /^!pw/) {
    get_pw($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^!pricewatch/  || $args =~ /^!pw/) {
    get_pw($conn, $event, $event->nick);
  }
}

sub get_pw {
  my $conn = shift;
  my $event = shift;
  my $who = shift;

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in pricewatch plugin...");
    return;
  }

  if($pid) {
    #parent
    
    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my $args;
    ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
    $args =~ s/^!pricewatch\s*//;
    $args =~ s/^!pw\s*//;

    my @words = split(' ', $args);
    
    my($remote,$port,$iaddr,$paddr,$proto,$line);
    $remote = "www.pricewatch.com";
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

    $msg = "GET /search/search.asp?criteria=";
    $i = 0;
    foreach $temp (@words) {
      $temp =~ tr/[A-Z]/[a-z]/;
      $msg = $msg . "$temp";
      $i++;
      if($i < @words) { $msg = $msg . '+'; }
    }
    $msg = $msg . "\n\n";

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($who, "Could not send to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    
    my $newplace = '';
    while(<SOCK>) {
      if($newplace eq '') {
	($newplace) = $_ =~ /.*?HREF=\"(.*?)\">.*/;
	if($newplace ne '') { last; }
      }
    }
    close SOCK;

    my $server;
    ($server) = $newplace =~ /http:\/\/(.*?)\//;

    $newplace =~ s/http:\/\/.*?\///;

    my $msg = "GET /" . $newplace . "\n\n";

    if(!defined($iaddr = inet_aton($server))) {
      $conn->privmsg($who, "Could not get address for $server");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($paddr = sockaddr_in($port, $iaddr))) {
      $conn->privmsg($who, "Could not get port for $server");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($proto = getprotobyname('tcp'))) {
      $conn->privmsg($who, "Could not get tcp protocol");
      $conn->{_connected} = 0;
      exit 1;
    }
    
    if(!socket(SOCK, PF_INET, SOCK_STREAM, $proto)) {
      $conn->privmsg($who, "Could not open socket to $server");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!connect(SOCK, $paddr)) {
      $conn->privmsg($who, "Could not connect to $server");
      $conn->{_connected} = 0;
      exit 1;
    }

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($who, "Could not send to $server");
      $conn->{_connected} = 0;
      exit 1;
    }

    my $price = '';
    my $brand = '';
    my $product = '';
    my $description = '';
    while (my $lala = <SOCK>) {

      $lala =~ s/&reg\;//g;
      $lala =~ s/&amp\;/&/g;

      if($brand eq '') {
	($brand) = $lala =~ /TARGET=\"Toolbar\"><b>(.*?)<\/b><\/a>/;
	next;
      }

      if($product eq '') {
	($product) = $lala =~ /<TD><font SIZE=\"-1\">(.*?)<\/font><\/td>/;
	next;
      }

      if ($description eq '') {
	($description) = $lala =~ /<TD><font SIZE=\"-1\">(.*?)<\/font><\/td>/;
	next;
      }

      if($price eq '') {
	($price) = $lala =~ /<b>(.*?)<\/b><INPUT TYPE=\"HIDDEN\"/;
	next;
      }
      
      if(($brand ne '') && ($product ne '') && ($price ne '')) {
	$conn->privmsg($who, "$price / $brand / $product / $description");
	close SOCK;
	$conn->{_connected} = 0;
	exit 0;
      }
    }

    $conn->privmsg($who, "No pricewatch matches found for: $args");
    close SOCK;
    $conn->{_connected} = 0;
    exit 0;
  }

  close SOCK;
  
}

1;
