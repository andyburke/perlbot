#!/usr/bin/perl

# perlbot-from-eggdrop.pl
# original author: Andrew Burke
#
# This converts a very simple eggdrop log file to a perlbot formatted
# log file... kinda...  You will very likely have to munge this script
# to make it work with your eggdrop logfile format.  A good idea for
# an improvement would be to make this script parse your eggdrop config
# file and figure out your logfile format.  We didn't do that since we
# had all our logs in one format and this worked for us.  :)
#
# If you improve this script, please send the new script or a patch
# to perlbot@fdntech.com .

use strict;

opendir(DIR, ".");
my @files = readdir(DIR);
close DIR;

foreach my $file (@files) {
  if($file == '.' || $file == '..') { next; }
  open FILE, $file;
  my @lines = <FILE>;
  close FILE;

  open TMP, ">tmp";

  my $i;
  foreach my $line (@lines) {
    $i = sprintf("%02.d", (($i + 1) % 60));;
    $line =~ s/(\[\d+\:\d+\]\s)Action\:\s/$1/;
    $line =~ s/\[(\d+)\:(\d+)\]/$1\:$2\:$i/;
    print TMP $line;
  }
  close TMP;

  `mv tmp $file`;
} 
