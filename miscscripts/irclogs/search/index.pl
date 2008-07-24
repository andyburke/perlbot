#!/usr/bin/perl

# enter your perlbot logs directory here
$directory = 'logs/';

#a perl script to search through irc logfiles
#and display occurences of specific words

use CGI qw/-compile :standard :html3 :netscape/;

opendir(DIRLIST, $directory);
DIRTO: foreach $diritem (readdir(DIRLIST)) {
  if (-d "$directory$diritem") {
    if ($diritem =~ /(\.\.?|^msg$)/) { next DIRTO }
  push @channels, $diritem;
  }
}
closedir(DIRLIST);

print header;
print start_html(-bgcolor=>'white',-text=>'black',-title=>'IRC log search',-style=>'A:link {text-decoration: none}'),
    img({-src=>'../logsearch.jpg'}),
    start_form,
    '<table border="0" cellspacing="5" cellpadding="0">',
    '<tr><td>What words would you like to search for:</td><td>',
    textfield('words'),
    '</td></tr>',
    '<tr><td>In which channel do you want to search:</td><td>',
    popup_menu(-name=>'channel',
			    -values=>\@channels,
	                    -default=>$channels[0]),
    '</td></tr>',
    '<tr><td></td><td>',
    submit,
    '</td></tr></table>',
    end_form,
    hr;

$channel = param('channel');
@the_words = split(' ', param('words'));

if (@the_words) {

  opendir(DIR, "$directory$channel/");
  @tmp = readdir(DIR);
  @files = sort(@tmp);

  foreach $file (@files) {
    open FILE, "$directory$channel/$file";
    @lines = <FILE>;
    close FILE;

    foreach $the_word (@the_words) {
      @lines = grep(/\Q$the_word\E/i, @lines);	
    }

    foreach (@lines) {
      s/</&lt;/g;
      s/>/&gt;/g;
    }

    if (@lines) {

      print "<b>";
      print a({href=>"../plog.pl?$channel\/$file"},"$file");	
      print "</b>";
      print "<PRE>";
      foreach(@lines) {
	s/(\d+:\d+:\d+)/<A HREF=\"..\/plog.pl?$channel\/$file#$1\">$1<\/A>/;
	print;
      }
      print "</PRE>";
    }
  }

  closedir(DIR);
  print br, hr;
}

print br, '<A HREF="../">Return to browsing the logs</A>';

print end_html;
