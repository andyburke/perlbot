package Perlbot::Logs::SingleFile;

# This module implements single-file logs, reusing much of the code from
# the standard multi-file logger, Logs::Files.


use strict;

use Perlbot::Utils;

use File::Spec;

use base qw(Perlbot::Logs::Files);



# base our filename on just channel name
sub filename {
  my $self = shift;

  return File::Spec->catfile($self->directory, strip_channel($self->channel) . '.log');
}


sub make_directories {
  my $self = shift;

  stat $self->directory or mkdir($self->directory, 0755);
}


# never roll logfile
sub should_roll {
  return undef;
}


sub line_prefix {
  my $self = shift;

  return '%timestamp ';  # the space is by design
}


sub parse_log_entry {
  my $self = shift;
  my ($text, $date_string) = @_;

  # Incoming date_string will be empty, so override it and remove the
  # date portion of the log line.
  $text =~ s|(\d\d\d\d/\d\d/\d\d)-||;
  $date_string = $1;

  return $self->SUPER::parse_log_entry($text, $date_string);
}


sub get_filelist {
  my $self = shift;
  my ($initialdate, $finaldate) = @_;

  return [$self->filename];  # it never changes
}

# note that initial/final_entry_time() are just inherited

1;
