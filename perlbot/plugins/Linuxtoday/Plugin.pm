# Joh, Yong-iL <tolkien@nownuri.net>
#
# This gets the latest Linuxtoday entries.

package Linuxtoday::Plugin;

use Perlbot;
use LWP::Simple;
use XML::Simple;
use URI::Escape;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my $conn = shift;
  my $event = shift;
  my $args;

  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^${pluginprefix}linuxtoday\s*/  || $args =~ /^${pluginprefix}lt\s*/) {
    if($args =~ /^${pluginprefix}linuxtoday\s+search.*/ || $args =~/^${pluginprefix}lt\s+search.*/) {
      get_lt_search($conn, $event, $event->{to}[0]);
    } else {
      get_lt($conn, $event, $event->{to}[0]);
    }
  }
}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $args;

  ($args = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;

  if($args =~ /^${pluginprefix}linuxtoday\s*/  || $args =~ /^${pluginprefix}lt\s*/) {
    if($args =~ /^${pluginprefix}linuxtoday\s+search.*/ || $args =~/^${pluginprefix}lt\s+search.*/) {
      get_lt_search($conn, $event, $event->nick);
    } else {
      get_lt($conn, $event, $event->nick);
    }
  }
}

sub get_lt {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $max;

  ($max = $event->{args}[0]) =~ tr/[A-Z]/[a-z]/;
  $max =~ s/^${pluginprefix}linuxtoday\s*//;
  $max =~ s/^${pluginprefix}lt\s*//;
  $max =~ s/\s+(\d+)\s*.*/$1/;

  if ($max < 1) { $max = 5; }

  if (!defined($pid = fork)) {
    $conn->privmsg($who, "error in linuxtoday plugin...");
    return;
  }

  if($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my $xml = get('http://linuxtoday.com/backend/linuxtoday.xml');
    if (!$xml) {
      $conn->privmsg($who, "error in linuxtoday plugin - failed to fetch http data");
    } else {

      $data = XMLin($xml);
      $conn->privmsg($who, "Linux Today headlines:");

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
	$conn->privmsg($who, $output);
	$i++;
      }
    }

    $conn->{_connected} = 0;
    exit 0;
  }

}

sub get_lt_search {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $args;
  my $max;

  $args = $event->{args}[0];

  my ($term, $max) = split(':', $args, 2);
  my $term_escaped;

  $term =~ s/^${pluginprefix}linuxtoday\s+search\s*//;
  $term =~ s/^${pluginprefix}lt\s+search\s*//;
  $term_escaped = uri_escape($term, '^a-zA-Z0-9');

  if ($max < 1) { $max = 3 }

  if(!defined($pid = fork)) {
    $conn->privmsg($who, "error in linuxtoday plugin...");
    return;
  }

  if($pid) {
    #parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child

    my $html = get('http://linuxtoday.com/search.php3?query='.$term_escaped);

    if (!$html) {
      $conn->privmsg($who, "error in linuxtoday plugin - failed to fetch http data");
    } elsif ($html =~ /No stories found matching query\./) {
      $conn->privmsg($who, "No Linux Today results found for: $term");
    } else {
      #my @results = $html =~ m#<a HREF="(/news_story.php3?.*?)">(.*?)</a>.*?<i>(.*?) </i>#gs;
      my @results = $html =~ m#(/news_story.php3\?.*?)">(.*?)</A>.*?&nbsp;<I>(.*?) </I>#gs;

      my $i = 1;
      while ($i <= $max and @results) {
        my ($link, $headline, $date) = splice(@results, 0, 3);
        my $output = sprintf('%s | %55.55s'."\n", $date, $headline);
        $conn->privmsg($who, $output);
        $conn->privmsg($who, '  http://linuxtoday.com'.$link);
        $i++;
      }
    }

    $conn->{_connected} = 0;
    exit 0;
  }

}



1;

