package Perlbot::Logs::Files;

use strict;

use Perlbot::Utils;
use Perlbot::Logs::Event;

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

  debug("Got call for field: $field", 15);

  if (!exists($FIELDS{$field})) {
    die "AUTOLOAD: no such method/field '$field'";
  }

  $self->{$field};
}

sub update_date {
  my $self = shift;

  $self->curtime = time();
}

# *CLASS* function to get the logdir from a config, with a default of 'logs'
# Do not call this as an object method, it will not work.  It's just a function.
sub directory_from_config {
  my $config = shift;

  return $config->exists(bot => 'logdir') ? $config->get(bot => 'logdir') : 'logs';
}

# object method to get the logdir for this object
sub directory {
  my $self = shift;

  directory_from_config($self->perlbot->config);
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

  $self->open unless $self->file->opened;

  unless (Perlbot::Utils::perlbot_date_filename(time()) eq
          Perlbot::Utils::perlbot_date_filename($self->curtime)) {
    debug("Rolling log file", 2);
    $self->open();
  }


#  $self->file->print($event->as_string . "\n");

  if ($event->type eq 'public') {
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
    $self->file->print($event->as_string_formatted($base . '[%type] %target was kicked by %nick (%text)') . "\n");
  } elsif($event->type eq 'join') {
    $self->file->print($event->as_string_formatted($base . '%nick (%userhost) joined %channel') . "\n");
  } elsif($event->type eq 'part') {
    $self->file->print($event->as_string_formatted($base . '%nick (%userhost) left %channel') . "\n");
  }

  $self->file->flush();
}


# This is hairy.  The regexps below need to match the above formatted
# log printing lines, 1 to 1.  Otherwise, log lines won't be parsed
# correctly for input.
#
# params:
#   - a line from a log
#   - the date string for the line (in perlbot format)
#
sub parse_log_entry {
  my $self = shift;
  my ($text, $date_string) = @_;
  my $rawevent;

  # must have a timestamp!
  $text =~ s/^(\d\d:\d\d:\d\d) // or return undef;
  $rawevent->{time} = Perlbot::Utils::ctime_from_perlbot_date_string("$date_string-$1");

  if      ($text =~ /^<(.*?)> (.*)$/) {
    @$rawevent{qw(type nick text)} = ('public', $1, $2);

  } elsif ($text =~ /^\* (.*?) (.*)$/) {
    @$rawevent{qw(type nick text)} = ('caction', $1, $2);

  } elsif ($text =~ /^(.*?) set mode: (.*)$/) {
    @$rawevent{qw(type nick text)} = ('mode', $1, $2);

  } elsif ($text =~ /^\[TOPIC\] (.*?): (.*)$/) {
    @$rawevent{qw(type nick text)} = ('topic', $1, $2);

  } elsif ($text =~ /^\[NICK\] (.*?) changed nick to: (.*)$/) {
    @$rawevent{qw(type nick text)} = ('nick', $1, $2);

  } elsif ($text =~ /^\[QUIT\] (.*?) quit: (.*)$/) {
    @$rawevent{qw(type nick text)} = ('quit', $1, $2);

  } elsif ($text =~ /^\[KICK\] (.*?) was kicked by (.*?) \((.*)\)$/) {
    @$rawevent{qw(type target nick text)} = ('kick', $1, $2, $3);

  } elsif ($text =~ /^(.*?) \((.*?)\) joined .*$/) {
    @$rawevent{qw(type nick userhost)} = ('join', $1, $2);

  } elsif ($text =~ /^(.*?) \((.*?)\) left .*$/) {
    @$rawevent{qw(type nick userhost)} = ('part', $1, $2);

  }

  $rawevent->{channel} = $self->channel;
  debug($rawevent);

  return $rawevent;
}

sub search {
  my $self = shift;
  my $args = shift;

  use Data::Dumper;
  print Dumper $args;

  my $maxresults = $args->{maxresults};
  my $terms = $args->{terms};
  my $nick = $args->{nick};
  my $type = $args->{type};
  my $initialdate = $args->{initialdate} || 1;
  my $finaldate = $args->{finaldate} || time();

  my @result;
  my $resultcount = 0;

  my $channel = Perlbot::Utils::strip_channel($self->channel);

  if (opendir(DIR, File::Spec->catfile($self->directory, $channel))) {
    my @tmp = readdir(DIR);
    my @files = sort(@tmp);

    FILE: foreach my $file (@files) {
      my $initialdate_string = Perlbot::Utils::perlbot_date_filename($initialdate);
      my $finaldate_string = Perlbot::Utils::perlbot_date_filename($finaldate);

      my $filedate_string = $file;
      $filedate_string =~ s|\.|/|g; # convert filename to date string

      next if $file lt $initialdate_string;
      last if $file gt $finaldate_string;

      CORE::open(FILE, File::Spec->catfile($self->directory, $channel, $file));
      my @lines = <FILE>;
      CORE::close FILE;

      $initialdate_string = Perlbot::Utils::perlbot_date_string($initialdate);
      $finaldate_string = Perlbot::Utils::perlbot_date_string($finaldate);

      foreach my $line (@lines) {
        chomp $line;
        my $rawevent = $self->parse_log_entry($line, $filedate_string);
        my $event = new Perlbot::Logs::Event($rawevent);
        debug($event->as_string);

        next if $event->time < $initialdate;
        last if $event->time > $finaldate;

        next if $nick and $event->nick ne $nick;
        next if $type and $event->type ne $type;

        my $add_to_result = 1;

        foreach my $term (@$terms) {
          if (defined $event->text and $event->text !~ /$term/i) {
            $add_to_result = 0;
            last;
          }
        }

        if ($add_to_result) {
          push(@result, $line);
          $resultcount++;
        }
        last FILE if defined($maxresults) and $resultcount >= $maxresults;
      }

    }
  }

  return @result;
}


sub DESTROY {
}

1;
