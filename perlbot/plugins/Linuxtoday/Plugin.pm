# Joh, Yong-iL <tolkien@nownuri.net>
#
# This gets the latest Linuxtoday entries.
#
# Updated by Jeremy Muhlich (jmuhlich@bitflood.org)
#  to use LWP::Simple, etc.
#
# Updated by Andrew Burke (burke@bitflood.org)
#  to use the new plugin interface

package Linuxtoday::Plugin;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use LWP::Simple;
use XML::Simple;
use URI::Escape;

sub init {
  my $self = shift;

  $self->hook('linuxtoday', \&lt);
  $self->hook('lt', \&lt);
}

sub lt {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  if($text =~ /^search/) {
    $text =~ s/^search\s+//i;

    my ($term, $max) = split(':', $text, 2);
    my $term_escaped;

    $term_escaped = uri_escape($term, '^a-zA-Z0-9');

    if ($max < 1) { $max = 3; }

    my $html = get('http://linuxtoday.com/search.php3?query=' . $term_escaped);

    if (!$html) {
      $self->reply_error('Error in linuxtoday plugin - failed to fetch http data!');
    } elsif ($html =~ /No stories found matching query\./) {
      $self->reply_error("No Linux Today results found for: $term");
    } else {
      my @results = $html =~ m#(/news_story.php3\?.*?)">(.*?)</A>.*?&nbsp;<I>(.*?) </I>#gs;

      my $i = 1;
      while ($i <= $max and @results) {
        my ($link, $headline, $date) = splice(@results, 0, 3);
        my $output = sprintf('%s | %55.55s'."\n", $date, $headline);
        $self->reply($output);
        $self->reply('  http://linuxtoday.com'.$link);
        $i++;
      }
    }
  } else {

    my $max;
    ($max = $text) =~ tr/[A-Z]/[a-z]/;
    $max =~ s/\s+(\d+)\s*.*/$1/;

    if ($max < 1) { $max = 5; }

    my $xml = get('http://linuxtoday.com/backend/linuxtoday.xml');
    if (!$xml) {
      $self->reply_error('Error in linuxtoday plugin - failed to fetch http data!');
    } else {

      $data = XMLin($xml);
      $self->reply('Linux Today headlines:');

      my $i = 1;
      foreach my $story (@{$data->{story}}) {
        last if $i > $max;

        my $title = $story->{title};
        my $time = $story->{time};

        $time =~ s/Jan/1/;
        $time =~ s/Feb/2/;
        $time =~ s/Mar/3/;
        $time =~ s/Apr/4/;
        $time =~ s/May/5/;
        $time =~ s/Jun/6/;
        $time =~ s/Jul/7/;
        $time =~ s/Aug/8/;
        $time =~ s/Sep/9/;
        $time =~ s/Oct/10/;
        $time =~ s/Nov/11/;
        $time =~ s/Dec/12/;
        $time =~ s/^(\d+) (\d+), (\d+), (.*)/$4/;

        my $output = sprintf("[%d/%02d/%02d %s] %s\n", $3, $1, $2, $time, $title);
        $self->reply($output);
        $i++;
      }
    }
  }
}

1;
