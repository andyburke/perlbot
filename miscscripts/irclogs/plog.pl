#!/usr/bin/perl

# enter your perlbot logs directory here
my $filename = 'logs/';

use strict;
use HTMLPlog;
use CGI qw/-compile :standard :html3 :netscape/;

my $p = shift;
$p =~ s/\.\.//g; # so people can't read arbitrary files

$filename .= $p;

print header;

HTMLPlog::makehtml($filename);
