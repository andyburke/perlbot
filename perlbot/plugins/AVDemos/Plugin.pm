
# fun      ace@cs.jhu.edu


package AVDemos::Plugin;

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

  if($args =~ /^${pluginchar}av-demos/) {
    get_avdemos($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^${pluginchar}av-demos/) {
    get_avdemos($conn, $event, $event->nick);
  }
}

sub get_avdemos {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $max;

  ($max = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
  $max =~ s/^${pluginchar}av-demos//;
  $max =~ s/\s+(\d+)\s*.*/$1/;

  if($max eq '' || $max < 1) { $max = 5; }

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in av-demos plugin...");
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
    $args =~ s/^${pluginchar}av-demos\s*//;
    
    my($remote,$port,$iaddr,$paddr,$proto,$line);
    $remote = "www.avault.com";
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

    $msg = "GET /\n\n";

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($who, "Could not send to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }


    my $i = 0;
    my $k =0;

    while (my $input = <SOCK>){
      if($input =~ m#<a href="/pcrl/" class="menu">LATEST DEMOS</a></font>#) {
	  $i++;
	  next;
      }
      if ($i == 1){
	  $i++;
	  next;
      }
      if ($i == 2){
          my $string;
          print "[AVDEMOS] BEFORE STRIPPING: $input\n" if $debug;
	  $input =~ s#<br>##g;
	  $input =~ s#</?b>##g;
	  $input =~ s#</?font.*?>##g;
          print "[AVDEMOS] AFTER STRIPPING: $input\n" if $debug;
	  @string = $input =~ m#(.*?)\s<a.*?\">(.*?)</a>#g;
          print "[AVDEMOS] LIST: ", join('|', @string), "\n";
	  $conn->privmsg($who, "AVault.com Demos: \n");
	  for (my $j =0;($j < @string) && ($k < $max); $j+=2){
	      $conn->privmsg($who, "    $string[$j] : $string[$j+1]");
	      $k++;
	  }
      }

      $i=0;
  }

    $conn->{_connected} = 0;
    exit 0;
  }
}

1;
