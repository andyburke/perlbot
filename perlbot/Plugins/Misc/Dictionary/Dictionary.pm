# Andrew Burke <burke@pas.rochester.edu>
#
# dictionary

package Perlbot::Plugin::Dictionary;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use LWP::Simple;

out $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->hook('dict', \&dictionary);
  $self->hook('dictionary', \&dictionary);
}

sub dictionary {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $max;

  $text =~ tr/[A-Z]/[a-z]/;
  ($text, $max) = split(' ', $text, 2);
  $max ||= 2;

  my $url = "http://www.ibiblio.org/webster/cgi-bin/headword_search.pl?query=${text}&=Submit";

  my $html = get($url);
  if (!$html) {
    $self->reply_error('Could not connect to Dictionary server!');
    return;
  }
    
  chomp $html;
  $html =~ s/\n//g;
  $html =~ s/&reg\;//g;
  $html =~ s/&amp\;/&/g;

  if($html =~ /0 matches/) {
    $self->reply_error("No such word found: $text");
    return;
  }

  my @tempwords;
  my %tmpwordshash;
  my @words;
  my $pos;
  my $ety;
  my @defs;

  @tempwords = $html =~ /<b><u>(.*?)<\/u><\/b>/ig;
  undef %tmpwordshash;
  @tmpwordshash{@tempwords} = ();
  @words = keys(%tmpwordshash);

  ($pos) = $html =~ /<i>(.*?)<\/i>/i;
  $pos =~ s/<.*?>//g;

  ($ety) = $html =~ /<ety>(.*?)<\/ety>/i;
  $ety =~ s/<.*?>//g;

  @defs = $html =~ /<def>(.*?)<\/def>/ig;

  $self->reply("Word(s): " . join(', ', @words));
  $self->reply("Part of Speech: $pos");
  $self->reply("Etymology: $ety");
  my $i = 1;
  foreach my $def (@defs) {
    if($i > $max) { last; }
    $def =~ s/<.*?>//g;
    $self->reply("  $i: $def");
    $i++;
  }

  if(@defs - ($i - 1) > 0) {
    $self->reply('[[ ' . (@defs - ($i - 1)) . ' definitions not displayed ]]');
  }

}

1;


