#!/usr/bin/perl

use File::Find;
use XML::Simple;
use strict;

my $dir;
my $data;

$dir = $ARGV[0];
if (!length($dir)) {
  print "Please specify your perlbot directory.\n";
  exit;
}

$data = {};
find(sub {wanted($data)}, $dir);
print XMLout($data, rootname => 'pluginreport', xmldecl => 1);


sub wanted {
  my ($data) = @_;

  my $infofile = "$_/info.xml";
  my $helpfile = "$_/help.xml";

  # Must be a directory with info.xml or help.xml and a.pm file of
  # the same name.
  -d $_ or return;
  -f $infofile or -f $helpfile or return;
  -f "$_/$_.pm" or return;

  my ($info, $rawhelp, $help);
  $info = XMLin($infofile) if -f $infofile;
  $rawhelp = XMLin($helpfile, forcearray=>1) if -f $helpfile;

  if (defined $rawhelp->{overview}) {
    if (ref($rawhelp->{overview}[0]) eq 'HASH') {
      $help->{overview} = $rawhelp->{overview}[0]{content};
    } else {
      $help->{overview} = $rawhelp->{overview};
    }
  }
  if (ref($rawhelp->{command}) eq 'HASH') {
    foreach my $command (keys(%{$rawhelp->{command}})) {
      $help->{command}{$command}{name} = $command;
      if ($rawhelp->{command}{$command}{content}) {
        if (ref($rawhelp->{command}{$command}{content}) eq 'ARRAY') {
          $help->{command}{$command}{content} = $rawhelp->{command}{$command}{content};
        } else {
          $help->{command}{$command}{content} = [$rawhelp->{command}{$command}{content}];
        }
      }
      if ($rawhelp->{usage}{$command}{content}) {
        push @{$help->{command}{$command}{content}}, "Usage: ".$rawhelp->{usage}{$command}{content};
      }
    }
  }

  $data->{plugin}{$_} = {
    name => $_,
    info => $info,
    help => $help,
  };
}

