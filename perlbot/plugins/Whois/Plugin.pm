################################################################
### Whois - Chris Thompson
################################################################

package Whois::Plugin;

use Perlbot;
use Net::Whois;
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

  if($args =~ /^${pluginchar}who(is|are)/) {
#    print "Checking $args\n";
    get_whois($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^${pluginchar}who(is|are)/) {
    get_whois($conn, $event, $event->nick);
  }
}

sub get_whois {
  my $conn = shift;
  my $event = shift;
  my $to = shift;

  if(!defined($pid = fork)) {
    $conn->privmsg($chan, "error in whois plugin...");
    return;
  }

  if($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my $args;
    my @domains;

    ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
    
    if ($args =~ /^\s*[${pluginchar}]*(who\w*) (.*)/i) {
      @multidomains = split(/ /, $2);
      if ($1 eq "whois") {
	push (@domains, @multidomains);
      }
      elsif ($1 eq "whoare") {
	foreach $sld (@multidomains) {
	  foreach $tld ("com","net","org") {
	    push (@domains, "$sld.$tld")
	  }
	}
      }
      foreach $chkdomain (@domains) {
	my $w = new Net::Whois::Domain $chkdomain; 
	undef $line;
	undef $line2;
	
	if ($w->domain) {
	  $line = $w->domain . " is taken by " . $w->name;
	  $line2 = "Since: " . $w->record_created;
	}
	else {
	  $line = "$chkdomain is available.";
	  $line2 = 0;
	}
	$conn->privmsg($to, $line);
	if ($line2) {
	  $conn->privmsg($to, $line2);
	  $line2 = 0;
	}
      }
    }
    $conn->{_connected} = 0;
    exit 0;
  }
}

1;
