################################################################
### Stock Quotes - Chris Thompson
################################################################

package Stock::Plugin;

use Perlbot;
use Finance::YahooQuote;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my $conn = shift;
  my $event = shift;
  my $args;

  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^![l]*quote/) {
    get_stock($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^[l]*quote/) {
    get_stock($conn, $event, $event->nick);
  }
}

sub get_stock {
  my $conn = shift;
  my $event = shift;
  my $to = shift;

  if(!defined($pid = fork)) {
    $conn->privmsg($chan, "error in stock plugin...");
    return;
  }

  if($pid) {
    $SIG{CHLD} = sub { wait; };
    return;

  } else {

    my $args;
    my @tickers;

    ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
    
    $args =~ /([l]*quote) (.*)/i;
    $mode = $1;
    @tickers = split(/ /, $2);

    @results = getquote(@tickers);

    foreach $r (@results) {
      ($sym, $name, $lastprice, $lastdate, $lasttime, $change, $percentchg,
       $volume, $avgdailyvol, $bid, $ask, $prevclose, $todayopen, $dayrange,
       $range52wk, $earnpershare, $peratio, $divpayrate, $divyield, $mktcap,
       $exchange) = @$r;
      
      $line = "$sym LAST: $lastprice $change ($percentchg) $name";
      $conn->privmsg($to , $line);

      if ($mode eq "lquote") {
	$conn->privmsg($to , "$sym VOL: $volume 52wkRange: $range52wk P/E: $peratio");
	$conn->privmsg($to , "$sym DayRange: $dayrange Div/Share: $divyield");
      }
    }
    $conn->{_connected} = 0;
    exit 0;
  }
}

1;


