#!/usr/bin/perl

use strict;

use Net::IRC;
use Perlbot;

my $userid = -1;

if( -f '.perlbot_user_id' ) {
  open(USERIDFILE, '.perlbot_user_id');
  $userid = <USERIDFILE>;
  chomp $userid;
  close(USERIDFILE);
}

print <<EOG;

Welcome to the Perlbot Feedback Agent!

This software allows the Perlbot developers to gather information
which can help us better meet the needs of our users.

This software will not report any sensitive information!  It is
solely intended to report information which can be used for
statistical and development purposes.

You will be able to view and approve the information being sent
before it is reported.

Some of the information will be gathered automatically, but you
will be asked a few questions.  This should only take a moment.


EOG

my $os = $^O;
my $perlbotversion = $Perlbot::VERSION;
my $perlversion = $];
my $netircversion = $Net::IRC::VERSION;

my $firsttime;
while($firsttime ne 'y' && $firsttime ne 'n') {
  print "Is this your first time running perlbot? [y/n] ";
  $firsttime = lc(<STDIN>);
  chomp $firsttime;
}
  
my $docshelpful;
while($docshelpful ne 'y' && $docshelpful ne 'n' && $docshelpful ne 's') {
  print "Was the included documentation (the manual, the FAQ, etc.) helpful? [y/n/s(omewhat)] ";
  $docshelpful = lc(<STDIN>);
  chomp $docshelpful;
}

my $docsimprovement;
if($docshelpful eq 'n' || $docshelpful eq 's') {
  print "Please type in a brief, single line of text telling us how you feel the documentation could be improved: ";
  $docsimprovement = <STDIN>;
  chomp $docsimprovement;
}

my $numchannels;
while($numchannels !~ /^\d+$/) {
  print "How many channels will this perlbot be used in? (estimate): ";
  $numchannels = <STDIN>;
  chomp $numchannels;
}

my $numusers;
while($numusers !~ /^\d+$/) {
  print "How many users will this perlbot have? (estimate): ";
  $numusers = <STDIN>;
  chomp $numusers;
}

my $load;
while($load ne 'l' && $load ne 'm' && $load ne 'h') {
  print "What will the load on this bot be like? (estimate) [l(ight)/m(oderate)/h(eavy)] ";
  $load = lc(<STDIN>);
  chomp $load;
}

my $usingwebserver;
while($usingwebserver ne 'y' && $usingwebserver ne 'n') {
  print "Will you be using the integrated webserver? [y/n] ";
  $usingwebserver = lc(<STDIN>);
  chomp $usingwebserver;
}

my $mostdesired;
print "What is your most desired future feature and/or plugin?: ";
my $mostdesired = <STDIN>;






######################
# end data gathering
######################

print "\n\nThe following information will be reported back to the Perlbot developers:\n\n";

print "OS              : $os\n";
print "Perlbot Version : $perlbotversion\n";
print "Perl Version    : $perlversion\n";
print "Net::IRC Version: $netircversion\n";
if($userid != -1) {
  print "Perlbot User ID : $userid\n";
}
print "------------------------------------\n";
print "First time user: $firsttime\n";
print "Documentation helpful: $docshelpful\n";
if($docshelpful eq 'n' || $docshelpful eq 's') {
  print "  Suggestions on improving documentation:\n";
  print "     $docsimprovement\n\n";
}
print "Estimated Channels: $numchannels\n";
print "Estimated Users: $numusers\n";
print "Estimated Load: $load\n";
print "Using Integrated Webserver: $usingwebserver\n";
print "Most desired feature/plugin:\n";
print "  $mostdesired\n\n";





