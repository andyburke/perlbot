# IRCStats
#
# by Andrew Burke (burke@bitflood.org)
#
# This was largely influenced by onis (http://verplant.org/onis/)
# and there's even a tiny bit of Florian Forster's code in here.

package Perlbot::Plugin::IRCStats;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);
use fields qw(datafile channels);

use XML::Simple;
use Perlbot::Utils;
use File::Spec;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->{datafile} = File::Spec->catfile($self->{directory}, 'channeldata.xml');

  if(!-f $self->{datafile}) {
    open(DATAFILE, '>' . $self->{datafile});
    print DATAFILE XMLout({}, rootname => 'channeldata');
    close DATAFILE;
  }
    
  $self->{channels} = XMLin($self->{datafile});

  $self->hook_event('public', \&public);
  $self->hook_event('caction', \&action);

  $self->hook_admin('updatestats', \&import_from_logs);

  $self->hook_web('ircstats', \&ircstats, 'IRC Stats');

  $self->perlbot->schedule(10, sub { $self->check_channel_membership() });

}

sub ircstats {
  my $self = shift;
  my @args = @_;

  if(!scalar @args) {
    my $response = "<html><head><title>IRC Stats</title></head>";

    $response .= "<body>Stats for channel:<p><ul>";

    foreach my $chan (sort(keys(%{$self->perlbot->channels}))) {
      $chan =~ s/\#//g;
      $response .= "<li><a href=\"/ircstats/$chan\">$chan</a>";
    }

    $response .= "</ul></body></html>";

    return ('text/html', $response);
  }

  if($args[0] && $args[0] eq 'pixel.jpg') {
    open(MYIMG, File::Spec->catfile($self->{directory}, 'pixel.jpg'));
    my $img;
    read(MYIMG, $img, 1024);
    close(MYIMG);
    return ('image/jpeg', $img);
  } elsif($args[0] && defined($self->{channels}{$args[0]})) {
    # dump stats for $channel
    
    my $chan = $args[0];
    my $response = "<html><head><title>IRC Stats</title></head><body>";
    
    $response .= "<p>Channel statistics for #$chan";
    
    $response .= "<p><center><table width=80% height=120 border=0><tr height=10><th colspan=24>Hourly Traffic</th></tr>";
    
    $response .= "<tr height=100>";
    
    my $totallines = 0;
    foreach my $hour (keys(%{$self->{channels}{$chan}})) {
      $totallines += $self->{channels}{$chan}{$hour};
    }

    my $highest_percentage = 0;
    for(my $hour = 0; $hour < 24; $hour++) {
      my $percentage;
      if(exists($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)})) {
        $percentage = sprintf("%0.0f", 100 * ($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)} / $totallines));
        if($percentage > $highest_percentage) { $highest_percentage = $percentage; }
      }
    }

    # TODO: test this better before putting it into production
    #if ($highest_percentage == 0) {
    #  debug("no data yet");
    #  return ('text/html', "No statistics yet for $chan.  You might ask an administrator to run ".
    #    $self->perlbot->config->get(bot=>'commandprefix')."updatestats on the bot to read statistics from logfiles.");
    #}

    my $normalization_factor = 100 / $highest_percentage;
    
    for(my $hour = 0; $hour < 24; $hour++) {
      my $percentage = 0;
      if(exists($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)})) {
        $percentage = sprintf("%0.0f", 100 * ($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)} / $totallines));
      }
      $response .= "<td width=4% valign=bottom align=middle><img src=\"/ircstats/pixel.jpg\" height=" . ($normalization_factor * $percentage) . " width=12></td>";
    }

    $response .= "</tr><tr height=10>";

    for(my $hour = 0; $hour < 24; $hour++) {
      $response .= "<td width=4% align=middle><font size=-1>" . sprintf("%02d", $hour) . "<br>";
      if(exists($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)})) {
        $response .= "(" . sprintf("%0.0f", 100 * ($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)} / $totallines)) . "%)";
      } else {
        $response .= "(0%)";
      }
      $response .= "</font></td>";
    }

    $response .= "</tr><tr>";

    $response .= "<td colspan=12><font size=-1>Average Channel Membership (hourly):" . sprintf("%d", $self->{channels}{$chan}{membership} / $self->{channels}{$chan}{membershipcheckcount}) . "</td>";

    $response .= "<td colspan=12 align=right><font size=-1>Total Lines: $totallines</font></td>";

    $response .= "</tr>";

    $response .= "</table></center>";

    $response .= "</body></html>";

    return('text/html', $response);
                      
  } else {
    return (undef, undef); #404
  }

}

sub public {
  my $self = shift;
  my $event = shift;

  my $chan = $event->{to}[0];
  $chan =~ s/\#//g;

  my ($sec, $min, $hour) = localtime(time());

  $self->{channels}{$chan}{'hour' . $hour}++;

#  open(DATAFILE, '>' . $self->{datafile});
#  print DATAFILE XMLout($self->{channels}, rootname => 'channeldata');
#  close DATAFILE;
}

sub action {
  my $self = shift;
  my $event = shift;

  my $chan = $event->{to}[0];
  $chan =~ s/\#//g;

  my ($sec, $min, $hour) = localtime(time());

  $self->{channels}{$chan}{'hour' . $hour}++;

#  open(DATAFILE, '>' . $self->{datafile});
#  print DATAFILE XMLout($self->{channels}, rootname => 'channeldata');
#  close DATAFILE;

}

sub logdir {
  my $self = shift;

  return Perlbot::LogFile::directory_from_config($self->perlbot->config);
}

sub import_from_logs {
  my $self = shift;

  $self->reply("Updating stats from logs...");

  foreach my $chan (keys(%{$self->{channels}})) {
    for(my $i=0; $i < 24; $i++) {
      my $hour = sprintf("%02d", $i);
      $self->{channels}{$chan}{'hour' . $hour} = 0;
    }
  }

  opendir(LOGSDIR, File::Spec->catfile($self->logdir));
  my @dirs = grep { !/^\./ } readdir(LOGSDIR);
  close(LOGSDIR);

  foreach my $channel (@dirs) {
    opendir(CHANLOGS, File::Spec->catfile($self->logdir, $channel));
    my @logs = grep { !/^\./ } readdir(CHANLOGS);
    close(CHANLOGS);
    foreach my $log (@logs) {
      open(LOG, File::Spec->catfile($self->logdir, $channel, $log));
      while(my $line = <LOG>) {
        if ($line =~ /^(\d\d):\d\d:\d\d\s<.*?>\s.+$/) {
          my $hour = $1;
          if(exists($self->{channels}{$channel}{'hour' . $hour})) {
            $self->{channels}{$channel}{'hour' . $hour}++;
          } else {
            $self->{channels}{$channel}{'hour' . $hour} = 1;
          }
        } elsif ($line =~ /^(\d\d):\d\d:\d\d\s\*\s\S+\s.+$/) {
          my $hour = $1;
          if(exists($self->{channels}{$channel}{'hour' . $hour})) {
            $self->{channels}{$channel}{'hour' . $hour}++;
          } else {
            $self->{channels}{$channel}{'hour' . $hour} = 1;
          }
        }
      }
      close(LOG);
    }
  }

  open(DATAFILE, '>' . $self->{datafile});
  print DATAFILE XMLout($self->{channels}, rootname => 'channeldata');
  close DATAFILE;

  $self->reply("Stats updated!");

}

sub check_channel_membership {
  my $self = shift;

  foreach my $channel (keys(%{$self->{channels}})) {
    my $chan;
    if($chan = $self->perlbot->get_channel($channel)) {
      $self->{channels}{$channel}{membership} += scalar keys(%{$chan->{members}});
      $self->{channels}{$channel}{membershipcheckcount}++;
    }
  }

  open(DATAFILE, '>' . $self->{datafile});
  print DATAFILE XMLout($self->{channels}, rootname => 'channeldata');
  close DATAFILE;

  $self->perlbot->ircconn->schedule(3600, sub { $self->check_channel_membership });
}

sub shutdown {
  my $self = shift;

  open(DATAFILE, '>' . $self->{datafile});
  print DATAFILE XMLout($self->{channels}, rootname => 'channeldata');
  close DATAFILE;
}

1;
















