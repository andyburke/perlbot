package Perlbot::Logs::Files;

use strict;

use Perlbot::Utils;
use Perlbot::Logs::Event;

use File::Spec;

use base qw(Perlbot::Logs);
use vars qw($AUTOLOAD %FIELDS);
use fields qw(curtime file);


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

# returns the filename we should be logging to at the moment
sub filename {
  my $self = shift;

  return File::Spec->catfile($self->directory,
                             Perlbot::Utils::strip_channel($self->channel),
                             Perlbot::Utils::perlbot_date_filename($self->curtime));
}

sub make_directories {
  my $self = shift;

  stat $self->directory or mkdir($self->directory, 0755);
  stat File::Spec->catfile($self->directory, strip_channel($self->channel))
      or mkdir(File::Spec->catfile($self->directory, strip_channel($self->channel)), 0755);
}

sub open {
  my $self = shift;
  my $filename;

  $self->close;
  $self->make_directories;
  $self->update_date;
  $filename = $self->filename;

  debug("Opening log file: $filename", 2);
  my $result = $self->file->open(">>$filename");
  $result or debug("Could not open logfile $filename: $!");
}

sub close {
  my $self = shift;
  $self->file->close if $self->file and $self->file->opened;
}

# returns true if we need to roll to another logfile
sub should_roll {
  my $self = shift;

  return Perlbot::Utils::perlbot_date_filename(time()) ne
    Perlbot::Utils::perlbot_date_filename($self->curtime);
}

sub line_prefix {
  my $self = shift;

  return '%hour:%min:%sec ';  # the space is by design
}

sub filename_to_datestring {
  my $self = shift;
  my $filename = shift;

#  $filename =~ s|.*?/(\d\d\d\d.\d\d.\d\d)$|$1|; # strip off any leading path
  $filename =~ s|^.*(\d\d\d\d).(\d\d)\.(\d\d)$|$1/$2/$3|;
  return $filename;
}

sub log_event {
  my $self = shift;
  my $event = shift;
  my $base = $self->line_prefix;

  $self->open unless $self->file->opened;
  if ($self->should_roll) {
    debug("Rolling log file", 2);
    $self->open;
  }

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

  $self->file->flush;
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

  } elsif ($text =~ /^\[topic\] (.*?): (.*)$/i) {
    @$rawevent{qw(type nick text)} = ('topic', $1, $2);

  } elsif ($text =~ /^\[nick\] (.*?) changed nick to: (.*)$/i) {
    @$rawevent{qw(type nick text)} = ('nick', $1, $2);

  } elsif ($text =~ /^\[quit\] (.*?) quit: (.*)$/i) {
    @$rawevent{qw(type nick text)} = ('quit', $1, $2);

  } elsif ($text =~ /^\[kick\] (.*?) was kicked by (.*?) \((.*)\)$/i) {
    @$rawevent{qw(type target nick text)} = ('kick', $1, $2, $3);

  } elsif ($text =~ /^(.*?) \((.*?)\) joined .*$/) {
    @$rawevent{qw(type nick userhost)} = ('join', $1, $2);

  } elsif ($text =~ /^(.*?) \((.*?)\) left .*$/) {
    @$rawevent{qw(type nick userhost)} = ('part', $1, $2);

  }

  $rawevent->{channel} = $self->channel;

  return $rawevent;
}

sub get_filelist {
  my $self = shift;
  my ($initialdate, $finaldate) = @_;
  my @files;
  my $channel = Perlbot::Utils::strip_channel($self->channel);

  my $initialdate_string = Perlbot::Utils::perlbot_date_filename($initialdate) if defined($initialdate);
  my $finaldate_string = Perlbot::Utils::perlbot_date_filename($finaldate) if defined($finaldate);

  if (! opendir(DIR, File::Spec->catfile($self->directory, $channel))) {
    return [];
  }

  while (my $file = readdir(DIR)) {
    $file =~ /\d\d\d\d\.\d\d\.\d\d/ or next;

    if ((!defined($initialdate_string) or $file ge $initialdate_string)
        and (!defined($finaldate_string) or $file le $finaldate_string)) {
      push @files, File::Spec->catfile($self->directory, $channel, $file);
    }
  }

  closedir(DIR);

  @files = sort @files;
  return \@files;
}

sub search {
  my $self = shift;
  my $args = shift;

  my $maxresults = $args->{maxresults};
  my $terms = $args->{terms}; 
  my $nick = $args->{nick}; $nick = undef if (defined($nick) and $nick eq '');
  my $type = $args->{type}; $type = undef if (defined($type) and $type eq '');
  my $initialdate = $args->{initialdate} || 1;
  my $finaldate = $args->{finaldate} || time();
  my $boolean = $args->{boolean} || 0;

  my @result;
  my $resultcount = 0;

  if($initialdate && $finaldate && $boolean
     && !$terms && !$nick && !$type) {
    my $channel = Perlbot::Utils::strip_channel($self->channel);

    my $curdate = $initialdate;
    do {
      my (undef, undef, undef, $d, $m, $y) = gmtime($curdate);
      $d = sprintf("%02d", $d);
      $m = sprintf("%02d", $m + 1);
      $y += 1900;
      
      if(-f File::Spec->catfile($self->directory, $channel, "$y.$m.$d")) {
        return 1;
      }
      $curdate += 86400; # add a day
    } while ($curdate < $finaldate);
    return 0;
  }
  
  my $files = $self->get_filelist($initialdate, $finaldate);

 FILE: foreach my $filename (@$files) {

    # we do a little pre-processing to speed up this search
    #
    # we eat the file, and throw away all the lines that don't
    # contain our search terms, if we have any

    if (! CORE::open(FILE, $filename)) {
      debug("failed to open '$filename' for searching: $!");
      next FILE;
    }

    my @lines = <FILE>;

    if(defined($terms) && @{$terms}) {
      foreach my $term (@$terms) {
        @lines = grep(/\Q$term\E/i, @lines);  
      }
    }

    #
    # end pre-processing

    # we still want to make sure our search term is in the right
    # place here, and that our dates are more fine-grained than
    # to the day, so we to some real conversions and searching
    # here...

    foreach my $line (@lines) {
      chomp $line;
      my $datestring = $self->filename_to_datestring($filename);
      my $rawevent = $self->parse_log_entry($line, $datestring);
      my $event = new Perlbot::Logs::Event($rawevent);

      next if $event->time < $initialdate;
      last if $event->time > $finaldate;

      next if defined($nick) and $event->nick ne $nick;
      next if defined($type) and $event->type ne $type;

      my $add_to_result = 1;

      if (defined($terms) && @{$terms}) {
        defined($event->text) or next;
        
        foreach my $term (@$terms) {
          if ($event->text !~ /$term/i) {
            $add_to_result = 0;
            last;
          }
        }
      }

      if ($add_to_result) {
        push(@result, $event) if wantarray();
        $resultcount++;
        last FILE if $boolean;
      }
      last FILE if defined($maxresults) and $resultcount >= $maxresults;
    }
    
    CORE::close FILE;
  }

  return wantarray() ? @result : $resultcount;
}

sub initial_entry_time {
  my $self = shift;

  my @files = @{$self->get_filelist()};

  my $firstfile = shift(@files);

  if(!CORE::open(FIRSTFILE, $firstfile)) {
    debug("failed to open '$firstfile': $!");
  }

  my $firstline = <FIRSTFILE>;

  CORE::close(FIRSTFILE);

  my $datestring = $self->filename_to_datestring($firstfile);
  my $rawevent = $self->parse_log_entry($firstline, $datestring);
  my $event = new Perlbot::Logs::Event($rawevent);

  return $event->time;
}

sub final_entry_time {
  my $self = shift;

  my @files = @{$self->get_filelist()};

  my $lastfile = pop(@files);

  if(!CORE::open(LASTFILE, $lastfile)) {
    debug("failed to open '$lastfile': $!");
  }

  my @lines = <LASTFILE>;

  CORE::close(LASTFILE);

  my $lastline = pop @lines;
  
  my $datestring = $self->filename_to_datestring($lastfile);
  my $rawevent = $self->parse_log_entry($lastline, $datestring);
  my $event = new Perlbot::Logs::Event($rawevent);

  return $event->time;

}


sub DESTROY {
}

1;
