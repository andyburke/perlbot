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
  my $event = shift;
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime($time);

  $year += 1900;
  $mon += 1;
  
  if (! $self->file->opened) { $self->open(); } 
  
  my $type = $event->type;
  my $nick = $event->nick;

  my $date = Perlbot::Utils::perlbot_date_string($time);

  my $logentry = "$date ";

  if($type eq 'public') {
    $logentry .= "<$nick> " . $event->{args}[0];
  } elsif($type eq 'caction') {
    $logentry .= "* $nick " . $event->{args}[0];
  } elsif($type eq 'join') {
    $logentry .= "$nick (" . $event->userhost . ") joined " . $self->channel;
  } elsif($type eq 'part') {
    $logentry .= "$nick (" . $event->userhost . ") left " . $self->channel;
  } elsif($type eq 'mode') {
    $logentry .= '[MODE] ' . $nick . ' set mode: ' . join(' ', @{$event->{args}});
  } elsif($type eq 'topic') {
    $logentry .= "[TOPIC] $nick: " . $event->{args}[0];
  } elsif($type eq 'nick') {
    my $newnick = $event->{args}[0];
    $logentry .= "[NICK] $nick changed nick to: $newnick";
  } elsif($type eq 'quit') {
    $logentry .= "[QUIT] $nick quit: " . $event->{args}[0];
  } elsif($type eq 'kick') {
    $logentry .= '[KICK] ' . $event->{to}[0] . ' was kicked by ' . $nick . ' (' . $event->{args}[1] . ')';
  } else {
    $logentry .= '[UNKNOWN EVENT]';
    debug('Unknown event log attempt:', 3);
    debug($event, 3);
  }

  $logentry =~ s/\n//g;
  $self->file->print($logentry . "\n");
  $self->file->flush();
}

1;
