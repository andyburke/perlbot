#!/usr/bin/perl

# Converts 1.x logs to 2.x format
# (adds the date to the timestamp on each line)


use strict;


if (!@ARGV) {
  print "Please specify a channel log directory (e.g. ../logs/channame).\n";
  exit 1;
}

if (! -d $ARGV[0]) {
  print "The specified parameter is not a valid directory.\n";
  exit 1;
}

while (my $filename = <$ARGV[0]/*>) {

  print "\n$filename\n";
  # does this filename look like a logfile?
  if ($filename !~ /(\d{4})\.(\d{2})\.(\d{2})$/) {
    print "  skipping - not a logfile\n";
    next;
  }
  print "  converting...\n";
  my $prefix = "$1/$2/$3-";

  open(TEMPOUT, '+>', undef); # anonymous temp file

  open(FILE, "<$filename");
  while (<FILE>) {
    # is this line already converted?
    if (m|^\d{4}/\d{2}/\d{2}-\d{2}:\d{2}:\d{2} |) {
      next;
    }
    print TEMPOUT "$1/$2/$3-$_";
  }
  close(FILE);

  # copy the content back to the logfile
  seek(TEMPOUT, 0, 0);
  open(FILE, ">$filename");
  print FILE while <TEMPOUT>;
  close(FILE);

  close(TEMPOUT);

}

