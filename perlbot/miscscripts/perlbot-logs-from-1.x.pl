#!/usr/bin/perl -i

use strict;

if (!@ARGV) {
  print "Please specify a channel log directory\n";
  print "  (e.g. .../perlbot/logs/channame)\n";
  exit 1;
}

while (my $filename = <$ARGV[0]/*>) {
  print "processing $filename\n";
  $filename =~ /(\d{4})\.(\d{2})\.(\d{2})$/ or next;
  my $prefix = "$1/$2/$3-";
  open(FILE, $filename);
  while (<FILE>) {
    if (! m|^\d{4}/\d{2}/\d{2}-\d{2}:\d{2}:\d{2} |) {
    }
    print "$1/$2/$3-$_";
  }
  close(FILE);
}

