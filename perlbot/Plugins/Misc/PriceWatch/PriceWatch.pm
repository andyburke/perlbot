# Andrew Burke <burke@pas.rochester.edu>
#
# This will get you the latest, lowest price from www.pricewatch.com

package Perlbot::Plugin::PriceWatch;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);

use LWP::Simple;
use HTML::TableExtract;

our $VERSION = '2.0.0';

sub init {
  my $self = shift;

  $self->hook('pw', \&pricewatch);
  $self->hook('pricewatch', \&pricewatch);
}

sub pricewatch {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  $text =~ tr/[A-Z]/[a-z]/;

  my @words = split(' ', $text);
    
  my $url = 'http://castle.pricewatch.com/search/search.idq?qc=';
  $url .= join('+AND+', @words);
  $url .= "+AND+%40totalcost%3E0";

  my $html = get($url);
  if (!$html) {
    $self->reply_error('Could not connect to PriceWatch server!');
    return;
  }
    
  $html =~ s/&reg\;//g;
  $html =~ s/&amp\;/&/g;

  my ($price, $dealer, $product, $description);
  my ($te, $row);

  $te = new HTML::TableExtract( headers => ['Dealer/Phone/State',
                                            'Product',
                                            'Description',
                                            'MaxTotalCost'] );
  $te->parse($html);
  $row = ($te->rows)[0];

  ($dealer) = $$row[0];
  $dealer =~ s/\n/ /g;
  $dealer =~ s/\s+/ /g;

  $product = $$row[1];
  $description = $$row[2];

  ($price) = $$row[3] =~ /(\$.*?\d+)/;
  $price =~ s/\s+//g;

  if ($dealer && $product && $price) {
    $dealer =~ s/\n//g;
    $product =~ s/\n//g;
    $price =~ s/\n//g;
    $self->reply("$price / $dealer / $product / $description");
  } else {
    $self->reply_error("No pricewatch matches found for: $text");
  }

}

1;



