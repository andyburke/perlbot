#!/usr/bin/perl

use strict;
use Socket;


my $userid = -1;

if( -f '.perlbot_user_id' ) {
  open(USERIDFILE, '.perlbot_user_id');
  $userid = <USERIDFILE>;
  chomp $userid;
  close(USERIDFILE);
}

print <<EOG;

Welcome to the Perlbot Feedback Agent!

This software  allows the  Perlbot developers  to gather information  which can
help us better meet your needs.

Don't  worry, we are  not gathering  any sensitive  information!  This  tool is
solely intended  to report  information which can  be used  for statistical and
development purposes,  such as your perl version and how  many users you expect 
to have.

Some data  will be  gathered automatically,  and you  will also be  asked a few
brief questions.  You will be able to review and approve all information before
it is reported.

You may press ctrl-c at any time to abort without sending any data.

--------------------------------------
(please press Enter after all answers)

EOG

my $os = $^O;
my $perlversion = $];

my $netircversion = '';
eval "use Net::IRC";
if ($@) {
  $netircversion = $@;
} else {
  $netircversion = $Net::IRC::VERSION;
}

my $perlbotversion;
eval "use Perlbot";
if ($@) {
  $perlbotversion = $@;
} else {
  $perlbotversion = $Perlbot::VERSION;
}

my $firsttime   = prompt("Is this your first time running perlbot? [y/n] ",
                         '^[yn]$', 1);
  
my $docshelpful = prompt("Did you find the manual and the FAQ helpful?".
                           " [y/n/s(omewhat)] ",
                         '^[yns]$', 1);

my $docsimprove = prompt("Please type in a brief, single line of text".
                           " telling us how you feel\nthe documentation".
                           " could be improved (if at all):\n> ");

my $numchannels = prompt("In roughly how many channels will this perlbot".
                           " be used? ",
                         '^\d+$');

my $numusers    = prompt("About how many users will this perlbot have? ",
                         '^\d+$');

my $load        = prompt("What do you expect the load on this bot to be?".
                           " [l(ight)/m(oderate)/h(eavy)] ",
                         '^[lmh]$', 1);

my $webserver   = prompt("Will you be using the integrated webserver?".
                           " [y/n/m(aybe)] ",
                         '^[ynm]$', 1);

my $mostdesired = prompt("What is your most desired future feature and/or".
                           " plugin?\n(answer on one line only)\n> ");


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
print "Suggestions on improving documentation:\n";
print "  $docsimprove\n\n";
print "Estimated Channels: $numchannels\n";
print "Estimated Users: $numusers\n";
print "Estimated Load: $load\n";
print "Using Integrated Webserver: $webserver\n";
print "Most desired feature/plugin:\n";
print "  $mostdesired\n\n";

foreach my $value ($os, $docsimprove, $mostdesired) {
  $value =~ s/&/&amp;/g;
  $value =~ s/"/&quot;/g;
  $value =~ s/</&lt;/g;
  $value =~ s/>/&gt;/g;
}

my $xml = qq{<?xml version="1.0"?>\n<perlbot-feedback os="$os" perlbotversion="$perlbotversion" perlversion="$perlversion" netircversion="$netircversion" firsttimeuser="$firsttime" docshelpful="$docshelpful" docsimprovement="$docsimprove" channels="$numchannels" users="$numusers" load="$load" usingwebserver="$webserver" mostdesired="$mostdesired" />};

my $viewxml = prompt("Would you like to view the xml output that will be".
                       " submitted? [y/n] ",
                     '^[yn]$', 1);

if($viewxml eq 'y') {
  print "\n\n" . $xml . "\n\n";
}

my $send = prompt("All data ready, send to perlbot developers? [y/n]",
                  '^[yn]$', 1);
if ($send eq 'n') {
  print "\n\nABORTED\n";
  exit;
}

my($remote,$port,$iaddr,$paddr,$proto,$line);
$remote = "www.fdntech.com";
$port = "80";
    
if(!defined($iaddr = inet_aton($remote))) {
  print "Could not get address for $remote\n";
  exit 1;
}

if(!defined($paddr = sockaddr_in($port, $iaddr))) {
  print "Could not get port for $remote\n";
  exit 1;
}

if(!defined($proto = getprotobyname('tcp'))) {
  print "Could not get tcp protocol\n";
  exit 1;
}
    
if(!socket(SOCK, PF_INET, SOCK_STREAM, $proto)) {
  print "Could not open socket to $remote\n";
  exit 1;
}

if(!connect(SOCK, $paddr)) {
  print "Could not connect to $remote\n";
  exit 1;
}

# some of this lifted from URI::Escape

my %escapes;
# Build a char->hex map
for (0..255) {
  $escapes{chr($_)} = sprintf("%%%02X", $_);
}

$xml =~ s/([^A-Za-z0-9\-_.!~*'()])/$escapes{$1}/g;

my $msg = "GET /perlbot/index.pl?xml=$xml\n\n";

if(!send(SOCK, $msg, 0)) {
  print "Could not send to $remote\n";
  exit 1;
}

if($userid == -1) {
  while(my $line = <SOCK>) {
    if($userid =~ /^\d+$/) { last; }
  }
}

close SOCK;

open(USERID, ">.perlbot_user_id");
print USERID $userid;
close(USERID);

print "All data sent, thank you for helping us meet the needs of perlbot users!\n";


sub prompt {
  my ($message, $regex, $force_lc) = @_;

  # check regex validity (on an empty string just in case?)
  eval "'' =~ /$regex/";
  if ($@) {
    warn "prompt: invalid regex: $regex";
  }

  my $line;
  do {
    print $message;
    $line = <STDIN>;
    chomp $line;
    $line = lc($line) if $force_lc;
  } while ($line !~ /$regex/);

  print "\n";
  return $line;
}
