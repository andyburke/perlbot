# Andrew Burke <burke@pas.rochester.edu>
#
# This looks up a word at www.m-w.com

package Dictionary::Plugin;

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

  if($args =~ /^!dictionary\s*/  || $args =~ /^!dict\s*/) {
    get_def($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^!dictionary\s*/  || $args =~ /^!dict\s*/) {
    get_def($conn, $event, $event->nick);
  }
}

sub get_def {
  my $conn = shift;
  my $event = shift;
  my $who = shift;

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in dictionary plugin...");
  } elsif($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my $args;
    ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
    $args =~ s/^!dictionary\s*//;
    $args =~ s/^!dict\s*//;

    my ($word, $max) = split(' ', $args);
    if($word eq '') {
      $conn->privmsg($who, "Must specify a word to look up...");
    }
    if($max eq '') {
      $max = 1;
    }

    my($remote,$port,$iaddr,$paddr,$proto,$line);
    $remote = "www.m-w.com";
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

    $msg = "GET /cgi-bin/dictionary?va=";
    $msg = $msg . $word;
    $msg = $msg . "\n\n";

    if(!send(SOCK, $msg, 0)) {
      $conn->privmsg($who, "Could not send to $remote");
      $conn->{_connected} = 0;
      exit 1;
    }

    my $entry = '';
    my $pronunciation = '';
    my $function = '';
    my $date = '';
    my @def;
    my $tempdef = '';

    while (my $lala = <SOCK>) {

      $lala =~ s/&reg\;//g;
      $lala =~ s/&amp\;/&/g;
      $lala =~ s/&auml\;/\(umlaut\)/g;

      if($lala =~ /.*?No entries found.*/) {
	$conn->privmsg($who, "No entries found that match: $word");
	$conn->{_connected} = 0;
	exit 0;
      }

      if($entry eq '') {
	($entry) = $lala =~ /.*?pre><br>(.*?)<\/b><br>/;
	$entry =~ s/<.*>//g;
	$entry =~ s/\s+/ /g;
	next;
      }

      if($pronunciation eq '') {
	($pronunciation) = $lala =~ /(.*?)<\/tt><br>/;
	$pronunciation =~ s/<.*>//g;
	$pronunciation =~ s/\s+/ /g;
	next;
      }

      if($function eq '') {
	($function) = $lala =~ /(.*?)<\/i><br>/;
	$function =~ s/<.*>//g;
	$function =~ s/\s+/ /g;
	next;
      }

      if($date eq '') {
	($date) = $lala =~ /(.*?)<br>/;
	$date =~ s/<.*>//g;
	$date =~ s/\s+/ /g;
	next;
      }

      if($tempdef eq '') {
	($tempdef) = $lala =~ /<b>(.*)/;
	$tempdef =~ s/<br>/\!hack\!/g;
	$tempdef =~ s/<.*?>//g;
	$tempdef =~ s/&lt\;/</g;
	$tempdef =~ s/&gt\;/>/g;
	$tempdef =~ s/\n//g;
	$tempdef =~ s/\s+/ /g;

	print "<$tempdef>\n";

	@def = split(/\!hack\!/, $tempdef);
	next;
      }
    }

    $conn->privmsg($who, $entry);
    $conn->privmsg($who, $pronunciation);
    $conn->privmsg($who, $function);
    $conn->privmsg($who, $date);

    my $i=1;
    my $num = 1;
    foreach(@def) { 
      if($_ ne '') {
	if($i > $max) { last; }

	s/\!hack\!//g;
	$conn->privmsg($who,  $_);
        $num++;
	$i++;
      }
    }

    close SOCK;
    $conn->{_connected} = 0;
    exit 0;
  }

  close SOCK;
}

1;

