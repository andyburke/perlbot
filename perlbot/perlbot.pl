#!/usr/bin/perl -w

use strict;
use Perlbot;
use Data::Dumper;

my $configfile = $ARGV[0];

my $perlbot = new Perlbot($configfile);

$perlbot->start();
