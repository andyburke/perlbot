
# fun      ace@cs.jhu.edu


package Blues::Plugin;

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

  if($args =~ /^${pluginchar}bluesnews/ || $args =~ /^${pluginchar}blues/) {
    get_bluesnews($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^${pluginchar}bluesnews/ || $args =~/^${pluginchar}blues/) {
    get_bluesnews($conn, $event, $event->nick);
  }
}

sub get_bluesnews {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $HARD_max = 50;
  my $max;


  ($max = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
  $max =~ s/^${pluginchar}bluesnews//;
  $max =~ s/^${pluginchar}blues//; 
  $max =~ s/\s+(\d+)\s*.*/\1/;

  if($max eq '' || $max < 1) { $max = 5; }
  if($max > $HARD_max) { $max = $HARD_max;}

  if(!defined($pid = fork)) {
    $conn->privmsg($chan, "error in bluesnews plugin...");
    return;
  }

  if($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my($remote,$port,$iaddr,$paddr,$proto,$line);
    $remote = "www.bluesnews.com";
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

    $conn->privmsg($who, "Bluesnews.com Headlines: \n");

    my $i = 0;

    while ((my $input = <SOCK>) && ( $i < $max)) {
      if( $input =~ m#<doghdl.*?>(.*?)</doghdl></a></a></strong></font><font.*?>&nbsp; \[(\d+:\d+ \w\w \w+) \(.*?\) (\w+) (\d+),# ) {
        print "[BLUES] MATCHED: $input\n" if $debug;
        my ($headline, $date) = ($1, "$3/$4 $2");
        print "[BLUES] EXTRACTED: $headline|$date\n" if $debug;

        $date =~ s/January/1/;
        $date =~ s/Febuary/2/;
        $date =~ s/March/3/;
        $date =~ s/April/4/;
        $date =~ s/May/5/;
        $date =~ s/June/6/;
        $date =~ s/July/7/;
        $date =~ s/August/8/;
        $date =~ s/September/9/;
        $date =~ s/October/10/;
        $date =~ s/November/11/;
        $date =~ s/December/12/;

        $conn->privmsg($who, "   $date : $headline");
        $i++;
      }
    }

    $conn->{_connected} = 0;
    exit 0;
  }
}

1;

