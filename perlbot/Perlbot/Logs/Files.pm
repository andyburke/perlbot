package Perlbot::Logs::Files;

use strict;

use Perlbot::Utils;
use Perlbot::Logs::Event;

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
  my $event = new Perlbot::Logs::Event(shift, $self->channel);
  my $base = '%hour:%min:%sec ';

  if (! $self->file->opened) { $self->open(); } 

  unless (Perlbot::Utils::perlbot_date_filename(time()) eq
          Perlbot::Utils::perlbot_date_filename($self->curtime)) {
    debug("Rolling log file", 2);
    $self->open();
  }
  

#  $self->file->print($event->as_string . "\n");

  if($event->type eq 'public') {
    $self->file->print($event->as_string_formatted($base . '<%nick> %text') . "\n");
  } elsif($event->type eq 'caction') {
    $self->file->print($event->as_string_formatted($base . '* %nick %text') . "\n");
  } elsif($event->type eq 'mode') {
    $self->file->print($event->as_string_formatted($base . '%nick set mode: %text') . "\n");
  } elsif($event->type eq 'topic') {
    $self->file->print($event->as_string_formatted($base . '[%type] %nick: %text') . "\n");
  } elsif($event->type eq 'nick') {
    $self->file->print($event->as_string_formatted($base . '[%type] %nick changed nick to: %text') . "\n");
  } elsif($event->type eq 'quit') {
    $self->file->print($event->as_string_formatted($base . '[%type] %nick quit: %text') . "\n");
  } elsif($event->type eq 'kick') {
    $self->file->print($event->as_string_formatted($base . '[%type] %target was kicked by %nick') . "\n");
  } elsif($event->type eq 'join') {
    $self->file->print($event->as_string_formatted($base . '%nick (%userhost) joined %channel') . "\n");
  } elsif($event->type eq 'part') {
    $self->file->print($event->as_string_formatted($base . '%nick (%userhost) left %channel') . "\n");
  }
    
  $self->file->flush();
}

sub search {
  my $self = shift;
  my $args = shift;

  use Data::Dumper;
  print Dumper $args;

  my $maxresults = $args->{maxresults};
  my $termsref = $args->{terms}; my @terms = @{$termsref};
  my $nick = $args->{nick};
  my $type = $args->{type};
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
        chomp $line;
        my $event = new Perlbot::Logs::Event($line, $self->channel);
        print $event->as_string() . "\n";

        next if $event->time < $initialdate;
        last if $event->time > $finaldate;

        next if $nick and $event->nick ne $nick;
        next if $type and $event->type ne $type;

        my $add_to_result = 1;

        foreach my $term (@terms) {
          if($event->text !~ /$term/i) {
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
