# Andrew Burke <burke@pas.rochester.edu>
#
# This will get you the latest, lowest price from www.pricewatch.com

package Perlbot::Plugin::PriceWatch;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

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
    
  my $url = 'http://queen.pricewatch.com/search/search.idq?qc=';
  $url .= join('+AND+', @words);
  $url .= "+AND+%40totalcost%3E0";

  my $html = get($url);
  if (!$html) {
    $self->reply_error('Could not connect to PriceWatch server!');
    return;
  }
    
  $html =~ s/&reg\;//g;
  $html =~ s/&amp\;/&/g;

  my ($price, $brand, $product, $description);
  my ($te, $row);

  $te = new HTML::TableExtract( headers => ['Brand',
                                            'Product',
                                            'Description',
                                            'MaxTotalCost'] );
  $te->parse($html);
  $row = ($te->rows)[0];

  ($brand) = $$row[0] =~ /(.*?)\W/;
  $product = $$row[1];
  $description = $$row[2];

  ($price) = $$row[3] =~ /(\$.*?\d+)/;
  $price =~ s/\s+//g;

  if ($brand && $product && $price) {
    $brand =~ s/\n//g;
    $product =~ s/\n//g;
    $price =~ s/\n//g;
    $self->reply("$price / $brand / $product / $description");
  } else {
    $self->reply_error("No pricewatch matches found for: $text");
  }

}

1;



