# Slashdot 
#   
# Andrew Burke (burke@bitflood.org)

package Perlbot::Plugin::Slashdot;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use LWP::Simple;
use XML::Simple;

sub init {
  my $self = shift;

  $self->hook('slashdot', \&slashdot);
}

sub slashdot {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  if($text =~ /^search/) {
    $text =~ s/^search\s+//i;
    my ($term, $max) = split(':', $text);
    $max or $max = 3;
    
    my $xml = get('http://slashdot.org/search.pl?content_type=rss&query=' . $term);

    my $data = XMLin($xml);

    $self->reply('Slashdot search results:');

    for($i = 0; $i < $max && $data->{item}[$i]; $i++) {
      my $short_title = $data->{item}[$i]->{title};
      $short_title =~ s/\(.*?\)$//;
      $short_title = substr($short_title, 0, 31);
      my $output = sprintf("%32s / %s\n", $short_title, $data->{item}[$i]->{link});
      $self->reply($output);
    }

  } else {

    my $max;
    ($max = $text) =~ tr/[A-Z]/[a-z]/;
    $max =~ s/\s+(\d+)\s*.*/\1/;

    if($max eq '') { $max = 5; }

    my $xml = get('http://slashdot.org/slashdot.xml');

    my $data = XMLin($xml);
    
    $self->reply('Slashdot headlines:');
    for($i = 0; $i < $max; $i++) {
      my $short_title = substr($data->{story}[$i]->{title}, 0, 31);
      my $output = sprintf("%32s / %10s / %8s\n", $short_title, $data->{story}[$i]->{author}, $data->{story}[$i]->{time});
      $self->reply($output);
    }
  }
}

1;

