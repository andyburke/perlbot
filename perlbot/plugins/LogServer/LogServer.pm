package Perlbot::Plugin::LogServer;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use HTTP::Daemon;
use HTTP::Response;
use HTTP::Headers;
use File::Spec;

sub init {
  my $self = shift;

  $self->want_msg(0);
  $self->want_public(0);

  $self->{logdir} = $self->{perlbot}->config('bot' => 'logdir');

  $self->hook_event('endofmotd', sub { $self->logserver });
  $self->hook_event('nomotd', sub { $self->logserver });

}

sub logserver {
  my $self = shift;
  my $logdir = $self->{logdir};
  my $server = HTTP::Daemon->new(LocalPort => 9000) || die;

  while (my $connection = $server->accept()) {
    while (my $request = $connection->get_request()) {
      if ($request->method() eq 'GET') {
        my $response = '<html><head><title>Perlbot Logs</title></head><body><center>Perlbot Logs</center><hr>';
        my ($garbage, $chan, $year, $month, $day) = split('/', $request->url->path());

        print "chan: $chan year: $year month: $month day: $day\n";

        if(!$chan) {
          if(opendir(DIR, $logdir)) {
            my @channels = readdir(DIR);
            closedir(DIR);

            use Data::Dumper;
            print Dumper(@channels);

            $response .= '<ul>';
            foreach my $channel (@channels) {
              if (-d File::Spec->catfile($logdir, $channel)) {
                if ($channel !~ /^(\.\.?|msg)$/) {
                  $response .= "<li><b><a href=\"/${channel}\">$channel</a></b>";
                }
              }
            }
            $response .= '</ul>';
          } else {
            $response .= 'Could not open the bot\'s logdir!';
          }
        }
        if($chan && !$year) {
          if(!opendir(LOGLIST, File::Spec->catfile($logdir, $chan))) {
            $response .= "No logs for channel: $chan";
          } else {
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

            $response .= "<p><h2>Logs for $chan in:</h2>";
            $response .= '<p><hr><p><ul>';
            foreach my $year (@years) {
              $response .= "<li><b><a href=\"/${chan}/${year}\">$year</a></b>";
            }
            $response .= '</ul>';
          }
        }
        if($chan && $year && !$month) {
          use HTML::CalendarMonth;

          if(!opendir(LOGLIST, File::Spec->catfile($logdir, $chan))) {
            $response .= "No logs for channel: $chan";
          } else {
            my @tmpfiles =  readdir(LOGLIST);
            my @logfiles = sort(@tmpfiles);
            close LOGLIST;

            $response .= "<center><h1>Logs for channel: $chan</h1></center>";
            $response .= '<p><hr>';
            
            $response .= "<p><center><h1>$year</h1></center>\n";
            $response .= "<table width=\"100%\" border=\"0\">\n  <tr valign=\"center\" align=\"center\">\n";
            foreach my $month ((1..12)) {
              $response .= "    <td width=\"25%\" valign=\"center\" align=\"center\">\n";
              $month = sprintf("%02d", $month);
              my $cal = HTML::CalendarMonth->new(year => $year, month => $month);
              foreach my $day ((1..31)) {
                my $paddedday = sprintf("%02d", $day);
                my $filename = "$year.$month.$paddedday"; 
                if(grep { /\Q$filename\E/ } @logfiles) {
                  $cal->item($day)->wrap_content(HTML::Element->new('a', href => "/${chan}/${year}/${month}/${paddedday}"));
                }
              }
              $response .= $cal->as_HTML();
              $response .= "</td>\n";
              if($month % 4 == 0) { $response .="  </tr>\n  <tr>\n"; }
            }
            $response .= "</table>\n";
          }
        }

        if($chan && $year && $month && !$day) {
          use HTML::CalendarMonth;

          if(!opendir(LOGLIST, File::Spec->catfile($logdir, $chan))) {
            $response .= "No logs for channel: $chan";
          } else {
            my @tmpfiles =  readdir(LOGLIST);
            my @logfiles = sort(@tmpfiles);
            close LOGLIST;

            $response .= "<center><h1>Logs for channel: $chan</h1></center>";
            $response .= '<p><hr>';

            $response .= "<p><center><h1>$year</h1></center>\n";
            $month = sprintf("%02d", $month);
            my $cal = HTML::CalendarMonth->new(year => $year, month => $month);
            foreach my $day ((1..31)) {
              my $paddedday = sprintf("%02d", $day);
              my $filename = "$year.$month.$paddedday";
              if(grep { /\Q$filename\E/ } @logfiles) {
                $cal->item($day)->wrap_content(HTML::Element->new('a', href => "/${chan}/${year}/${month}/${paddedday}"));
              }
            }
            $response .= $cal->as_HTML();
          }
        }

        if($chan && $year && $month && $day) {
          my $filename = File::Spec->catfile($logdir, $chan, "$year.$month.$day");

          if(open(FILE, $filename)) {
            my @lines = <FILE>;
            close(FILE);

            foreach (@lines) {
              s/</\&lt\;/g;
              s/>/\&gt\;/g;
              s/(\&lt\;.*?\&gt\;)/<b>$1<\/b>/;
              s|^(\d+:\d+:\d+) \* (\w+) (.*)|$1 * <b>$2</b> $3|;
              s/^(\d+:\d+:\d+\s)(.*? joined \#.*?$)/$1<font color=\"blue\">$2<\/font>/;
              s/^(\d+:\d+:\d+\s)(.*? left \#.*?$)/$1<font color=\"blue\">$2<\/font>/;
              s/^(\d+:\d+:\d+\s)(\[.*?\])/$1<font color\=\"red\">$2<\/font>/;
              s/(\d+\:\d+:\d+)/<a name=\"$1\">$1<\/A>/;
              $response .= "<tt>$_</tt><br>";
            }
          }
        }                               
          

        $response .= '</body></html>';
        $connection->send_response(HTTP::Response->new(HTTP::Response::RC_OK,
                                                       'yay!',
                                                       HTTP::Headers->new(Content_Type => 'text/html;'),
                                                       $response));
      }
    }
    $connection->close;
    undef($connection);
  }
}

1;

