package Perlbot::Logs::FlatFile;

use strict;

use Perlbot::Utils;

use File::Spec;

use base qw(Perlbot::Logs);
use vars qw($AUTOLOAD %FIELDS);
use fields qw(channel curtime file);

sub new {
  my ($class, $perlbot, $channel) = @_;
  my ($mday,$mon,$year);

  my $self = fields::new($class);

  $self->perlbot = $perlbot;
  $self->channel = $channel;
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
 
  return directory_from_config($self->perlbot->config);
}

sub open {
  my $self = shift; 
  my $filename;

  $self->close;

  stat $self->directory or mkdir($self->directory, 0755);
    
  $filename = File::Spec->catfile($self->directory, strip_channel($self->channel) . '.log');

  debug("Opening log file: $filename", 2);
  my $result = $self->file->open(">>$filename");
  $result or debug("Could not open logfile: $filename: $!");
}

sub close {
  my $self = shift;
  $self->file->close if $self->file and $self->file->opened;
}

sub log_event {
  my $self = shift;
  my $event = new Perlbot::Logs::Event(shift, $self->channel);
  
  if (! $self->file->opened) { $self->open(); } 
  
  $self->file->print($event->as_string . "\n");
  $self->file->flush();
}

1;
