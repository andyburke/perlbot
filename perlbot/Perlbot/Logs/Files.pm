package Perlbot::Logs::Files;

use strict;

use Perlbot::Utils;

use File::Spec;

use base qw(Perlbot::Logs);
use vars qw($AUTOLOAD %FIELDS);
use fields qw(channel curtime file);

# note: This used to be called 'Log' instead of 'Logs', but when we put
# perlbot into CVS, Log created problems with keyword substitution.
# So it's called Logs now.
# Actually now it's called LogFile.
# Really, it's now totally different.

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
 
  return $self->directory_from_config($self->perlbot->config);
}

sub open {
  my $self = shift; 
  my $filename;

  $self->close;
  stat $self->directory or mkdir($self->directory, 0755);
  stat File::Spec->catfile($self->directory, strip_channel($self->channel))
      or mkdir(File::Spec->catfile($self->directory, strip_channel($self->channel)), 0755);
    
  $self->update_date();
  $filename = File::Spec->catfile($self->directory,
                                  Perlbot::Utils::strip_channel($self->channel),
                                  Perlbot::Utils::perlbot_date_filename($self->curtime));
    
  debug("Opening log file: $filename", 2);
  my $result = $self->file->open(">>$filename");
  $result or debug("Could not open logfile $filename: $!");
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

  unless (Perlbot::Utils::perlbot_date_filename($time) eq
          Perlbot::Utils::perlbot_date_filename($self->curtime)) {
    debug("Rolling log file", 2);
    $self->open();
  }
  
  my $date = Perlbot::Utils::perlbot_date_string($time);

  my $type = $event->type;
  my $nick = $event->nick;

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

sub search {
  my $self = shift;
  my $args = shift;

  use Data::Dumper;
  print Dumper $args;

  my $maxresults = $args->{maxresults};
  my $termsref = $args->{terms}; my @terms = @{$termsref};
  my $initialdate = $args->{initialdate} || 1;
  my $finaldate = $args->{finaldate} || time();

  my @result;
  my $resultcount = 0;

  my $channel = Perlbot::Utils::strip_channel($self->channel);

  if(opendir(DIR, File::Spec->catfile($self->perlbot->config->get(bot => 'logdir'), $channel))) {
    my @tmp = readdir(DIR);
    my @files = sort(@tmp);

    foreach my $file (@files) {
      my $initialdate_string = Perlbot::Utils::perlbot_date_filename($initialdate);
      my $finaldate_string = Perlbot::Utils::perlbot_date_filename($finaldate);

      next if $file lt $initialdate_string;
      last if $file gt $finaldate_string;

      CORE::open(FILE, File::Spec->catfile($self->perlbot->config->get(bot => 'logdir'), $channel, $file));
      my @lines = <FILE>;
      CORE::close FILE;

      $initialdate_string = Perlbot::Utils::perlbot_date_string($initialdate);
      $finaldate_string = Perlbot::Utils::perlbot_date_string($finaldate);

      foreach my $line (@lines) {
        next if $line lt $initialdate_string;
        last if $line gt $finaldate_string;
        my $add_to_result = 1;

        foreach my $term (@terms) {
          if($line !~ /$term/i) {
            $add_to_result = 0;
            last;
          }
        }

        if($add_to_result) {
          push(@result, $line);
          $resultcount++;
        }
        last if defined($maxresults) and $resultcount >= $maxresults;
      }
      last if defined($maxresults) and $resultcount >= $maxresults;
    }
  }

  return @result;
}

1;
