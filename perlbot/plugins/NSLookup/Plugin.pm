# Andrew Burke <burke@pas.rochester.edu>
#
# does an nslookup...
#

package NSLookup::Plugin;

use Perlbot;
use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg};
}

sub on_public {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^!nslookup/) {
   lookup($conn, $event, $event->{to}[0]);
  }
}  

sub on_msg {
  my $conn = shift;
  my $event = shift;

  if ($event->{args}[0] =~ /^!nslookup/) {
    lookup($conn, $event, $event->nick);
  }
}  

sub lookup {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $in;

  if (!defined($pid = fork)) {
    $conn->privmsg($chan, "error in nslookup plugin... weird.");
    return;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...

    ($in = $event->{args}[0]) =~ s/^!nslookup\s*//;

    $in =~ s/\`//g; #security?
    $in =~ s/\$//g;
    $in =~ s/\|//g;

    # really this might be better done w/ a gethostbyname() type thing...

    if($in eq '') {
      $conn->privmsg($who, "you must specify a host to look up...");
      $conn->{_connected} = 0;
      exit 1;
    }

    my @lookup = `nslookup $in`;
    chomp @lookup;

    my $server = '';
    my $name = '';
    my $address = '';

    foreach(@lookup) {
      if(($_ =~ /Server:/) && ($server eq '')) {
	$server = $_;
	$server =~ s/.*?Server:\s+(.*?)/\1/;
	next;
      }
      if(($_ =~ /Name:/) && ($name eq '')) {
	$name = $_;
	$name =~ s/.*?Name:\s+(.*?)/\1/;
	next;
      }
      if(($_ =~ /Address:/) && (($name ne '') && ($address eq ''))) {
	$address = $_;
	$address =~ s/.*?Address:\s+(.*?)/\1/;
	next;
      }
	
      if(($server ne '') && ($name ne '') && ($address ne '')) {
	$conn->privmsg($who, "$name : $address / Server: $server");
	$conn->{_connected} = 0;
	exit 0;
      }

    }

    $conn->privmsg($who, "$in not found: has no DNS entry on $server");
    $conn->{_connected} = 0;
    exit 0;			# kill child
  }
}

1;
