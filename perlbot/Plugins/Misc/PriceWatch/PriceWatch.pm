# Andrew Burke <burke@pas.rochester.edu>
#
# This will get you the latest, lowest price from www.pricewatch.com

package Perlbot::Plugin::PriceWatch;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use LWP::Simple;
use HTML::TableExtract;

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

  my $html = get($url);
  if (!$html) {
    $self->reply_error('Could not connect to PriceWatch server!');
    return;
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
    $self->reply("$price / $shipping / $brand / $product / $description");
  } else {
    $self->reply_error("No pricewatch matches found for: $text");
  }

}

1;

