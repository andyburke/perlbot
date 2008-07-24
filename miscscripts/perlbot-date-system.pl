#!/usr/bin/perl

# perlbot-date-system.pl
# original author: Andrew Burke
#
# This basically takes eggdrop filenames and makes them into
# perlbot ones.  It's not y2k compliant, it needs work and
# is meant as a jumping off point for you.  Also, it calls out
# to the 'mv' unix command, so you'll need to modify it to
# work on win32 or other non-unix platforms.
#
# If you improve this script, please send the new script or a patch
# to perlbot@fdntech.com .

use strict;

opendir(DIR, ".");
my @files = readdir(DIR);
close DIR;

my $chan = shift;

foreach my $file (@files) {
  my $newfile = $file;

  $newfile =~ s/$chan\.log\.(\d+)(.*?)(\d+)/19$3\.$2\.$1/;
  $newfile =~ s/Jan/01/;
  $newfile =~ s/Feb/02/;
  $newfile =~ s/Mar/03/;
  $newfile =~ s/Apr/04/;
  $newfile =~ s/May/05/;
  $newfile =~ s/Jun/06/;
  $newfile =~ s/Jul/07/;
  $newfile =~ s/Aug/08/;
  $newfile =~ s/Sep/09/;
  $newfile =~ s/Oct/10/;
  $newfile =~ s/Nov/11/;
  $newfile =~ s/Dec/12/;

  `mv $file $newfile`;
}
 
