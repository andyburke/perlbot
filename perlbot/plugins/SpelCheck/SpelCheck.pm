# SpelCheck
# =========
#
# Jeremy Muhlich <jmuhlich@jhu.edu>
#
# This plugin does spell-checking using ispell.  Prolly needs to be on
# a unix system...
#
# based on:
# infobot copyright (C) kevin lenzo 1997-98

package Perlbot::Plugin::SpelCheck;

use Plugin;
@ISA = qw(Plugin);

use Perlbot;
use POSIX;
use strict;

sub init {
  my $self = shift;

  $self->hook('spell', \&spell);
}

sub spell {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  # kill all punctuation that might piss off ispell, or the shell (?)
  $text =~ tr/\w //c;
  
  $text =~ s/\`//g;
  $text =~ s/\$//g;
  $text =~ s/\|//g;
  
  # -S means sort by probability of correctness
  # -a means take input from stdin
  my @spell = `echo "$text"| aspell -S -a 2>&1`;
  my $ok = 1;
  chomp(@spell);
  foreach my $line (@spell) {
    my ($code, $word, $suggest, $response);
    ($code, $word, undef, undef, $suggest) = split(' ', $line, 5);
    # The code tells us how the dictionary lookup went:
    # * -> the spelling was OK
    # + -> the word was found via affix removal (i.e. it's OK)
    # - -> the word was found; it's a compund (i.e. it's OK)
    # & -> the word wasn't found, but ispell has some near misses and guesses
    # ? -> the word wasn't found, but ispell has some guesses
    # # -> the word wasn't found, and ispell has no idea what you're talking about
    # NOTE: We ignore the guesses, so only print the near misses from &,
    #       and treat ? like #.  Also, we don't pass -C, so code - should
    #       never come up.  But OK spellings are just ignored, so it
    #       will work ok if somehow -C does get passed.
    if ($code eq '&') {
      $response = "$word: $suggest";
      $ok = 0;
    } elsif ($code eq '#' or $code eq '?') {
      $response = "$word... stop talking nonsense";
      $ok = 0;
    }
    $self->reply($response);
  }
  $self->reply('All words checked out OK') if $ok;

}

1;
