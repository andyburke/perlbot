#!/usr/bin/perl

use strict;

use File::Spec;
use XML::Simple;

my $logdir = shift;

$logdir or die "usage:\n  ./logdirimport.pl <pathtoperlbotlogdir>\n";

my $datafile = File::Spec->catfile('channeldata.xml');

if(!-f $datafile) {
  open(DATAFILE, '>' . $datafile);
  print DATAFILE XMLout(undef, rootname => 'channeldata');
  close DATAFILE;
}

my $xmlref = XMLin($datafile);
my %channels = %{$xmlref};


opendir(LOGSDIR, File::Spec->catfile($logdir)) or die "Couldn't open $logdir!";
my @dirs = grep { !/^\./ } readdir(LOGSDIR);
close(LOGSDIR);

foreach my $channel (@dirs) {
  opendir(CHANLOGS, File::Spec->catfile($logdir, $channel));
  my @logs = grep { !/^\./ } readdir(CHANLOGS);
  close(CHANLOGS);
  foreach my $log (@logs) {
    open(LOG, File::Spec->catfile($logdir, $channel, $log));
    while(my $line = <LOG>) {
      if ($line =~ /^(\d\d):\d\d:\d\d\s<.*?>\s.+$/) {
        my $hour = $1;
        if(exists($channels{$channel}{'hour' . $hour})) {
          $channels{$channel}{'hour' . $hour}++;
        } else {
          $channels{$channel}{'hour' . $hour} = 1;
        }
      } elsif ($line =~ /^(\d\d):\d\d:\d\d\s\*\s\S+\s.+$/) {
        my $hour = $1;
        if(exists($channels{$channel}{'hour' . $hour})) {
          $channels{$channel}{'hour' . $hour}++;
        } else {
          $channels{$channel}{'hour' . $hour} = 1;
        }
      }
    }
    close(LOG);
  }
}

open(DATAFILE, '>' . $datafile);
print DATAFILE XMLout(\%channels, rootname => 'channeldata');
close DATAFILE;


        



