package Perlbot::LogFile;

use Perlbot::Utils;
use strict;

use File::Spec;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(config chan curtime file);

# note: This used to be called 'Log' instead of 'Logs', but when we put
# perlbot into CVS, Log created problems with keyword substitution.
# So it's called Logs now.
# Actually now it's called LogFile.

sub new {
  my ($class, $chan, $config) = @_;
  my ($mday,$mon,$year);

  my $self = fields::new($class);
  
  $self->chan = $chan;
  $self->config = $config;
  $self->curtime = time();
  $self->file = new IO::File;

  return $self;
}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  if(!exists($FIELDS{$field})) {
    return;
  }

  debug("Got call for field: $field", 15);

  $self->{$field};
}

sub update_date {
  my $self = shift;

  $self->curtime = time();
}

# *class* function to get the logdir from a config, with a default of 'logs'
sub directory_from_config {
  my $config = shift;

  return $config->exists(bot => 'logdir') ? $config->get(bot => 'logdir') : 'logs';
}

# object method to get the logdir for this object
sub directory {
  my $self = shift;
 
  return directory_from_config($self->config);
}

sub singlelogfile {
  my $self = shift;

  return lc($self->config->get(channel => $self->chan => 'singlelogfile')) eq 'yes';
}

sub open {
  my $self = shift; 
  my $filename;

  if ($self->singlelogfile) {
    # user wants a single logfile per channel, not one file per day
    $self->close;

    stat $self->directory or mkdir($self->directory, 0755);
    
    $filename = File::Spec->catfile($self->directory, strip_channel($self->chan) . '.log');

    debug("Opening log file: $filename", 2);
    my $result = $self->file->open(">>$filename");
    $result or debug("Could not open logfile: $filename: $!");
  } else {
    # this is the standard behavior, one logfile per day
    # make necessary dirs if they don't exist
    $self->close;
    stat $self->directory or mkdir($self->directory, 0755);
    stat File::Spec->catfile($self->directory, strip_channel($self->chan))
      or mkdir(File::Spec->catfile($self->directory, strip_channel($self->chan)), 0755);
    
    $self->update_date();
    $filename = File::Spec->catfile($self->directory, strip_channel($self->chan), Perlbot::Utils::perlbot_date_filename($self->curtime));
    
    debug("Opening log file: $filename", 2);
    my $result = $self->file->open(">>$filename");
    $result or debug("Could not open logfile $filename: $!");
  }

}

sub close {
  my $self = shift;
  $self->file->close if $self->file and $self->file->opened;
}

sub write {
  my $self = shift;
  my $logentry = shift;
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime($time);

  $year += 1900;
  $mon += 1;
  
  if (! $self->file->opened) { $self->open(); } 

  if (! $self->singlelogfile) {
    # if the date has changed, roll the log file
    unless (Perlbot::Utils::perlbot_date_filename($time) eq
            Perlbot::Utils::perlbot_date_filename($self->curtime)) {
      debug("Rolling log file", 2);
      $self->open();
    }
  }
  
  my $date = Perlbot::Utils::perlbot_date_string($time);
  $logentry =~ s/\n//g;
  $self->file->print("$date " . $logentry . "\n");
  $self->file->flush();
}


1;
