# Andrew Burke <burke@pas.rochester.edu>
#
# This will get you the latest, lowest price from www.pricewatch.com

package PriceWatch::Plugin;

use strict;

use Perlbot;

use LWP::Simple;
use HTML::TableExtract;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my ($conn, $event) = @_;
  my $args;

  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if ($args =~ /^${pluginprefix}pricewatch/  || $args =~ /^${pluginchar}pw/) {
    get_pw($conn, $event, $event->{to}[0]);
  }
}

sub on_msg {
  my ($conn, $event) = @_;
  my $args;
 
  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if ($args =~ /^${pluginprefix}pricewatch/  || $args =~ /^${pluginchar}pw/) {
    get_pw($conn, $event, $event->nick);
  }
}

sub get_pw {
  my ($conn, $event, $chan) = @_;
  my ($pid);

  if (!defined($pid = fork)) {
    $conn->privmsg($chan, "error in pricewatch plugin...");
    return;
  }

  if ($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my $args;
    ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
    $args =~ s/^${pluginprefix}pricewatch\s*//;
    $args =~ s/^${pluginprefix}pw\s*//;
    $args =~ tr/[A-Z]/[a-z]/;

    my @words = split(' ', $args);
    
    my $url = 'http://queen.pricewatch.com/search/search.idq?qc=';
    $url .= join('+AND+', @words);

    my $html = get($url);
    if (!$html) {
      $conn->privmsg($chan, "Could not connect to PriceWatch server.");
      $conn->{_connected} = 0;
      exit 1;
    }
    
    $html =~ s/&reg\;//g;
    $html =~ s/&amp\;/&/g;

    my ($price, $brand, $product, $description, $shipping);
    my ($te, $row);

    $te = new HTML::TableExtract( headers => [qw(Brand Product Description Price Ship)] );
    $te->parse($html);
    $row = ($te->rows)[0];

    ($brand) = $$row[0] =~ /(.*?)\W/;
    $product = $$row[1];
    $description = $$row[2];

    ($price) = $$row[3] =~ /(\$.*?\d+)/;
    $price =~ s/\s+//g;

    ($shipping) = $$row[4];

    if ($brand && $product && $price) {
      $conn->privmsg($chan, "$price / $shipping / $brand / $product / $description");
    } else {
      $conn->privmsg($chan, "No pricewatch matches found for: $args");
    }

    $conn->{_connected} = 0;
    exit 0;
  }
}

1;

