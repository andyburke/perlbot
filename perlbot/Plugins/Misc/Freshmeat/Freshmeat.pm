# Andrew Burke <burke@pas.rochester.edu>
#
# This gets the latest Freshmeat entries.

package Perlbot::Plugin::Freshmeat;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use LWP::Simple;

sub init {
  my $self = shift;
  
  $self->author('Andrew Burke');
  $self->contact('burke@bitflood.org');
  $self->version('1.0.0');
  $self->url('http://perlbot.sourceforge.net');

  $self->hook('freshmeat', \&freshmeat);
  $self->hook('fm', \&freshmeat);
}

sub freshmeat {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  
  my $max;
  
  ($max = $text) =~ tr/[A-Z]/[a-z]/;
  $max =~ s/\s+(\d+)\s*.*/$1/;
  
  if($max eq '') { $max = 5; }
  
  my $url = "http://freshmeat.net/backend/recentnews.txt";
  
  my @html = split('\n', get($url));
  
  my $headline = '';
  my $link = '';
  my $date = '';
  my $formatteddate = '';
  
  $self->reply('Freshmeat Headlines:');
  
  my $i = 1;
  while ($i <= $max) {
    
    $headline = shift @html;
    chomp $headline;
    $headline =~ s/\(.*?\)$//;
    
    $date = shift @html;
    chomp $date;
    my ($year) = $date =~ /.*?(\d\d\d\d).*?/;
    my ($month) = $date =~ /.*?(January|February|March|April|May|June|July|August|September|October|November|December).*?/;
    my ($day) = $date =~ /.*?(\d+)[th|st]/;
    my ($time) = $date =~ /.*?(\d+:\d+).*?/;
    
    $month =~ s/January/01/;
    $month =~ s/February/02/;
    $month =~ s/March/03/;
    $month =~ s/April/04/;
    $month =~ s/May/05/;
    $month =~ s/June/06/;
    $month =~ s/July/07/;
    $month =~ s/August/08/;
    $month =~ s/September/09/;
    $month =~ s/October/10/;
    $month =~ s/November/11/;
    $month =~ s/December/12/;
    
    $formatteddate = sprintf("%04d/%02d/%02d %s", $year, $month, $day, $time);
    
    $link = shift @html;
    chomp $link;
    
    if(($headline ne '') && ($date ne '') && ($link ne '')) {
      
      if($i > $max) { last; }
      my $short_title = substr($headline, 0, 18);
      my $output = sprintf("%18s / %16s / %s", $short_title, $formatteddate, $link);
      $self->reply($output);
      
      $headline = '';
      $link = '';
      $date = '';
      $formatteddate = '';
    }
    $i++;
  }
}

1;







