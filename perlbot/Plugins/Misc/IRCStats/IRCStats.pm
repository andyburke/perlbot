package Perlbot::Plugin::IRCStats;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use XML::Simple;
use Perlbot::Utils;
use File::Spec;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_fork(0);
  $self->want_msg(0);

  $self->{datafile} = File::Spec->catfile($self->{directory}, 'channeldata.xml');

  if(!-f $self->{datafile}) {
    open(DATAFILE, '>' . $self->{datafile});
    print DATAFILE XMLout(undef, rootname => 'channeldata');
    close DATAFILE;
  }
    
  $self->{channels} = XMLin($self->{datafile});

  $self->hook_event('public', \&public);
  $self->hook_event('caction', \&action);

  $self->hook_web('ircstats', \&ircstats, 'IRC Stats');

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
    
    $response .= "<p><center><table width=80% height=150 border=0><tr><th colspan=24>Hourly Traffic</th></tr>";
    
    $response .= "<tr>";
    
    my $totallines = 0;
    foreach my $hour (keys(%{$self->{channels}{$chan}})) {
      $totallines += $self->{channels}{$chan}{$hour};
    }
    
    for(my $hour = 0; $hour < 24; $hour++) {
      my $percentage = 0;
      if(exists($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)})) {
        $percentage = sprintf("%0.0f", 100 * ($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)} / $totallines));
      }
      $response .= "<td width=4% valign=bottom align=middle><img src=\"/ircstats/pixel.jpg\" height=$percentage width=12></td>";
    }

    $response .= "</tr><tr>";

    for(my $hour = 0; $hour < 24; $hour++) {
      $response .= "<td width=4% align=middle><font size=-1>" . sprintf("%02d", $hour) . "<br>";
      if(exists($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)})) {
        $response .= "(" . sprintf("%0.0f", 100 * ($self->{channels}{$chan}{'hour' . sprintf("%02d", $hour)} / $totallines)) . "%)";
      } else {
        $response .= "(0%)";
      }
      $response .= "</font></td>";
    }

    $response .= "</tr></table></center>";
                      
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

  open(DATAFILE, '>' . $self->{datafile});
  print DATAFILE XMLout($self->{channels}, rootname => 'channeldata');
  close DATAFILE;
}

sub action {
  my $self = shift;
  my $event = shift;

  my $chan = $event->{to}[0];
  $chan =~ s/\#//g;

  my ($sec, $min, $hour) = localtime(time());

  $self->{channels}{$chan}{'hour' . $hour}++;

  open(DATAFILE, '>' . $self->{datafile});
  print DATAFILE XMLout($self->{channels}, rootname => 'channeldata');
  close DATAFILE;

}


1;
















