package Perlbot::Logs;

use Perlbot::Utils;
use strict;

use File::Spec;

# note: This used to be called 'Log' instead of 'Logs', but when we put
# perlbot into CVS, Log created problems with keyword substitution.
# So it's called Logs now.

sub new {
  my ($class, $logdir, $chan, $singlelogfile) = @_;
  my ($mday,$mon,$year);

  (undef,undef,undef,$mday,$mon,$year) = localtime;
  $year += 1900; #yay, y2k!
  $mon += 1;
  
  my $self = {
    logdir      => $logdir,
    chan        => $chan,
    curyr       => $year,
    curmon      => $mon,
    curday      => $mday,
    singlelogfile => $singlelogfile,
    file        => new IO::File
      };
  
  bless $self, $class;
  return $self;
}

sub chan {
  my $self = shift;
  $self->{chan} = shift if @_;
  return $self->{chan};
}

sub curyr {
  my $self = shift;
  $self->{curyr} = shift if @_;
  return $self->{curyr};
}

sub curmon {
  my $self = shift;
  $self->{curmon} = shift if @_;
  return $self->{curmon};
}

sub curday {
  my $self = shift;
  $self->{curday} = shift if @_;
  return $self->{curday};
}

sub singlelogfile {
  my $self = shift;
  $self->{singlelogfile} = shift if @_;
  return $self->{singlelogfile};
}

sub update_date {
  my $self = shift;
  my ($mday,$mon,$year);
  
  (undef,undef,undef,$mday,$mon,$year) = localtime;
  $year += 1900; #yay, y2k!
  $mon += 1;
  
  debug("Updating date to: $year.$mon.$mday for channel: $self->{chan}");
  
  $self->curyr($year);
  $self->curmon($mon);
  $self->curday($mday);
}

sub open {
  my $self = shift; 
  my $date;

  if ($self->singlelogfile) {
    # user wants a single logfile per channel, not one file per day
    $self->close;

    stat $self->{logdir} or mkdir($self->{logdir}, 0755);

    debug("Opening log file: " . File::Spec->catfile(strip_channel($self->{chan}) . '.log'), 2);
    my $result = $self->{file}->open(">>" . File::Spec->catfile($self->{logdir}, strip_channel($self->chan) . '.log'));
    $result or debug("Could not open logfile " . File::Spec->catfile($self->{logdir}, strip_channel($self->chan) . '.log') . ": $!");
  } else {
    # this is the standard behavior, one logfile per day
    # make necessary dirs if they don't exist
    $self->close;
    stat $self->{logdir} or mkdir($self->{logdir}, 0755);
    stat File::Spec->catfile($self->{logdir}, strip_channel($self->chan)) or mkdir(File::Spec->catfile($self->{logdir}, strip_channel($self->chan)), 0755);
    
    $self->update_date();
    $date = sprintf("%04d.%02d.%02d", $self->curyr, $self->curmon, $self->curday);
    
    debug("Opening log file: " . File::Spec->catfile(strip_channel($self->{chan}) , $date), 2);
    my $result = $self->{file}->open(">>" . File::Spec->catfile($self->{logdir}, strip_channel($self->chan), "$date"));
    $result or debug("Could not open logfile " . File::Spec->catfile($self->{logdir}, strip_channel($self->chan), "$date") . ": $!");
  }

}

sub close {
  my $self = shift;
  $self->{file}->close if $self->{file} and $self->{file}->opened;
}

sub write {
  my $self = shift;
  my $logentry = shift;
  my ($sec,$min,$hour,$mday,$mon,$year);
  my $date;
  
  ($sec,$min,$hour,$mday,$mon,$year) = localtime;
  $year += 1900;
  $mon += 1;
  
  if (! $self->{file}->opened) { $self->open(); } 

  if (! $self->singlelogfile) {
    # if the date has changed, roll the log file
    unless ($mday==$self->curday and $mon==$self->curmon and $year==$self->curyr) {
      debug("Rolling log file", 2);
      $self->open();
    }
  }
  
  $date = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
  $logentry =~ s/\n//g;
  $self->{file}->print("$date " . $logentry . "\n");
  $self->{file}->flush();
}


1;
