# Andrew Burke <burke@pas.rochester.edu>
#
# This will get you the latest, lowest price from www.pricewatch.com

package PriceWatch::Plugin;

use Perlbot;

use Socket;
use POSIX;

use HTML::TableExtract;

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
  my $chan = shift;

  if(!defined($pid = fork)) {
    $conn->privmsg($chan, "error in pricewatch plugin...");
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
      $conn->privmsg($chan, "Could not get address for $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($paddr = sockaddr_in($port, $iaddr))) {
      $conn->privmsg($chan, "Could not get port for $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($proto = getprotobyname('tcp'))) {
      $conn->privmsg($chan, "Could not get tcp protocol");
      $conn->{_connected} = 0;
      exit 1;
    }
    
    if(!socket(SOCK, PF_INET, SOCK_STREAM, $proto)) {
      $conn->privmsg($chan, "Could not open socket to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!connect(SOCK, $paddr)) {
      $conn->privmsg($chan, "Could not connect to $remote");
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
      $conn->privmsg($chan, "Could not send to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    
    my $newplace = '';
    while(<SOCK>) {
      if($newplace eq '') {
	($newplace) = $_ =~ /Location\:\s+(.*?)$/;
	if($newplace ne '') { last; }
      }
    }
    close SOCK;

    my $server;
    ($server) = $newplace =~ /http:\/\/(.*?)\//;
    $newplace =~ s/http:\/\/.*?\///;

    my $msg = "GET /" . $newplace . "\n\n";

    if(!defined($iaddr = inet_aton($server))) {
      $conn->privmsg($chan, "Could not get address for $server");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($paddr = sockaddr_in($port, $iaddr))) {
      $conn->privmsg($chan, "Could not get port for $server");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!defined($proto = getprotobyname('tcp'))) {
      $conn->privmsg($chan, "Could not get tcp protocol");
      $conn->{_connected} = 0;
      exit 1;
    }
    
    if(!socket(SOCK, PF_INET, SOCK_STREAM, $proto)) {
      $conn->privmsg($chan, "Could not open socket to $server");
      $conn->{_connected} = 0;
      exit 1;
    }
    if(!connect(SOCK, $paddr)) {
      $conn->privmsg($chan, "Could not connect to $server");
      $conn->{_connected} = 0;
      exit 1;
    }

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($chan, "Could not send to $server");
      $conn->{_connected} = 0;
      exit 1;
    }

    my $price = '';
    my $brand = '';
    my $product = '';
    my $description = '';
    my $shipping = '';

    my $html_string;

    while (my $lala = <SOCK>) {
      $lala =~ s/&reg\;//g;
      $lala =~ s/&amp\;/&/g;
      $html_string = $html_string . $lala;
    }

    $te = new HTML::TableExtract( headers => [qw(price brand product description shipping)] );

    $te->parse($html_string);

    my @rows = $te->rows;
    my $row = $rows[0];

    ($price) = $$row[0] =~ /(\$.*?\d+)/;
    $price =~ s/\s+//g;

    $brand = $$row[1];
    $product = $$row[2];
    $description = $$row[3];

    $shipping = $$row[4];
    $shipping  =~ s/\s\s+//gs; #(\w+.*)[\n|\s*]/;

    if(($brand ne '') && ($product ne '') && ($price ne '')) {
      $conn->privmsg($chan, "$price / $shipping / $brand / $product / $description");
      close SOCK;
      $conn->{_connected} = 0;
      exit 0;
    }

    $conn->privmsg($chan, "No pricewatch matches found for: $args");
    close SOCK;
    $conn->{_connected} = 0;
    exit 0;
  }

  close SOCK;
  
}

1;

