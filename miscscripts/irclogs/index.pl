#!/usr/bin/perl

# enter your perlbot logs directory here
my $directory = 'logs/';

use strict;
use CGI qw/-compile :standard :html3 :netscape/;
use HTML::CalendarMonth;
use HTML::Element;

print header;

print start_html(-bgcolor=>'white',-text=>'black',-title=>'IRC logs',
		 -style=>'A:link {text-decoration: none}');

opendir(DIRLIST, $directory);
my @diritems = readdir(DIRLIST); #for readability
closedir(DIRLIST);

my $chan;
my $year;

if(!param()) {
  print img({-src=>'logsearch.jpg'}), br;
  print "    <H2>Logs for channels:</H2>\n";
  print "    <P>\n";
  print "    <HR>\n";
  print "    <P>\n";

  print "    <UL>\n";
  foreach my $diritem (@diritems) {
    if (-d "$directory$diritem") {
      if (!($diritem =~ /^(\.\.?|msg)$/)) {
	print "    <LI><B><A HREF=\"index.pl?chan=$diritem\">$diritem</A></B>\n";
      }
    }
  }
  print "    </UL>\n";

} else {

  $chan = param('chan');
  $year = param('year');

  if(!opendir(LOGLIST, "$directory$chan")) {
    print "No logs for channel: $chan\n";
    exit 1;
  }

  my @tmpfiles =  readdir(LOGLIST);
  my @logfiles = sort(@tmpfiles);
  close LOGLIST;

  my @years;

  foreach my $logfile (@logfiles) {
    if (!($logfile =~ /^\.\.?$/)) {
      my ($tmpyear) = $logfile =~ /^(\d+)\./;

      if(!grep { /$tmpyear/ } @years) { push(@years, $tmpyear); }
    }
  }

  if(!$year) {
    print "    <H2>Logs for $chan in:</H2>\n";
    print "    <P>\n";
    print "    <HR>\n";
    print "    <P>\n";

    print "    <UL>\n";
    
    foreach my $year (@years) {
      print "<LI><B><A HREF=\"index.pl?chan=$chan&year=$year\">$year</A></B>\n";
    }

    print "    </UL>\n";
  } else {
  
    print "<center><h1>Logs for channel: $chan</h1></center>";
    print "<p><hr>";

#    foreach my $year (@years) {
      print "<p><center><h1>$year</h1></center>\n";
      print "<table width=\"100%\" border=\"0\">\n  <tr valign=\"center\" align=\"center\">\n";
      foreach my $month ((1..12)) {
        print "    <td width=\"25%\" valign=\"center\" align=\"center\">\n";
        $month = sprintf("%02d", $month);
        my $cal = HTML::CalendarMonth->new(year => $year, month => $month);
        foreach my $day ((1..31)) {
          my $paddedday = sprintf("%02d", $day);
          my $filename = "$year.$month.$paddedday"; 
          if(grep { /\Q$filename\E/ } @logfiles) {
            $cal->item($day)->wrap_content(HTML::Element->new('a', href => "plog.pl?$chan/$filename"));
          }
        }
        print $cal->as_HTML();
        print "</td>\n";
        if($month % 4 == 0) { print "  </tr>\n  <tr>\n"; }
      }
      print "</table>\n";
#    }

#  print "    <UL>\n";
#  foreach my $logfile (@logfiles) {
#    if (!($logfile =~ /^\.\.?$/)) {
#      my ($tmpyear = $logfile) =~ /^(\d\d\d\d)/;
#      my ($tmpmonth = $logfile) =~ /^\d\d\d\d\.(\d\d)/;
#
#      if(!$curyear) { $curyear = $tmpyear; }
#      if(!$tmpmonth) { $curmonth = $tmpmonth; }
#
#      
#      print "      <LI><A HREF=\"plog.pl?$chan/$logfile\">$logfile</A>\n";
#    }
#  }
#  print "    </UL>\n";
  }
}

print hr, br;

if (param()) {
  if($year) { print "<A HREF=\"index.pl?chan=$chan\">Return to the list of years for $chan</A>\n", br; }
  print '<A HREF="index.pl">Return to the list of channels</A>', br;
}

print '<A HREF="search/index.pl">Search the logs</A>', end_html;



