package Perlbot::Utils;

use strict;

use IO::File;
use File::Spec;
use XML::Simple;
use Carp;

use vars qw(
            @ISA @EXPORT
            );
require Exporter;

@ISA = qw(Exporter);

# symbols to export
@EXPORT = qw(
             &read_generic_config &write_generic_config
             &normalize_channel &strip_channel
             &validate_hostmask &hostmask_to_regexp
             &exec_command
             &debug &set_debug
          );

my $DEBUG;
if(defined($ENV{PERLBOT_DEBUG})) {
  if($ENV{PERLBOT_DEBUG} !~ /\D+/) {
    $DEBUG = $ENV{PERLBOT_DEBUG};
  } else {
    warn("WARNING: Your PERLBOT_DEBUG variable was non-numerical, debugging not enabled!!\n\n");
  }
}
$DEBUG ||= 0;

sub debug {
  my $ref = shift;
  my $level = shift;
  my ($package, $filename, $line) = caller();


  $level ||= 1;

  if($DEBUG >= $level) {
    if(!ref($ref)) { # we didn't get a reference, we assume it's a string
      print "($$) $package: $ref\n";
      return;
    }
    if(ref($ref) eq 'SCALAR') {
      print "($$) $package: $ref\n";
      return;
    }
    if(ref($ref) eq 'CODE') {
      &$ref;
      return;
    }
  }
}

sub set_debug {
  my $level = shift;

  if(defined($level)) {
    $DEBUG = $level;
  }

  return $DEBUG;
}

sub read_generic_config {
  my ($filename) = @_;

  my $fh = new IO::File($filename);

  if ($fh) {
    return XMLin($fh, forcearray => 1);
  } else {
    return undef;
  }
}

sub write_generic_config {
  my ($filename, $hashref) = @_;

  ($filename && $hashref) or return 0;

  my $xml = XMLout($hashref, rootname => 'config');
  if (! open(CONFIG, ">$filename")) {
    return undef;
  }
  print CONFIG $xml;
  close CONFIG;
}


sub normalize_channel {
  my $channel = shift;
  $channel = "#$channel" if $channel !~ /^[\#\&].*/;
  $channel =~ tr/\[\]\\/\{\}\|/;
  $channel =~ tr/[A-Z]/[a-z]/;
  return $channel;
}


sub strip_channel {
  my $channel = shift;
  $channel =~ s/^[#&]//;
  return $channel;
}


sub validate_hostmask {
  my ($hostmask) = (@_);

  $hostmask or return 0;

  if ($hostmask !~ /^[^!@]+![^!@]+@[^!@]+$/) {
    debug("validate_hostmask: '$hostmask' has bad syntax");
    return undef;
  }
  if ($hostmask =~ /!\*@/ or $hostmask =~ /@[\*\.]*$/) {
    debug("validate_hostmask: '$hostmask' is an open hostmask (insecure)");
    return undef;
  }
  return 1;
}


# Converts an RFC 1459 IRC hostmask (with * as a glob wildchar) into a
# regular expression.
# params:
#   $hostmask : hostmask to convert
# returns:
#   A regular expression representation of $hostmask
sub hostmask_to_regexp {
  my ($hostmask) = @_;

  # split hostmask into nick and userhost, since the rules differ
  my ($nick, $userhost) = $hostmask =~ /^(.*)!(.*)$/;

  # Substitutions to take a standard IRC hostmask and convert it to
  #   a regexp.  I thought this was pretty clever...  :)

  # {}| are really the lowercase equivalents of []\  (Don't ask me... read RFC1459)
  # The result of this is that { is equivalent to [ in a nick, etc.
  # I couldn't do a direct substitution for each of these.  There would
  #   be problems with the inserted ] and \ chars (used to define the
  #   character classes on the right side of the s///) being picked up
  #   by the second and third s/// expressions.  The solution was to
  #   substitute a character that would never be found in a real hostmask
  #   in a first pass, and convert those characters to the correct
  #   regexp in a second pass.
  # First pass: convert each instance of a char (upper or lower) to some
  #   'impossible' character.  (ascii 01, 02, and 03)
  $nick =~ s/[{[]/\01/g;
  $nick =~ s/[}\]]/\02/g;
  $nick =~ s/[|\\]/\03/g;
  # Second pass: convert each impossible char to the appropriate regexp
  $nick =~ s/\01/[{[]/g;
  $nick =~ s/\02/[}\\]]/g;
  $nick =~ s/\03/[|\\\\]/g;

  $userhost =~ s/([[\]{}|\\])/\\$1/g; # escape \[]{} only in userhost

  $hostmask = "$nick!$userhost";      # recombine
  $hostmask =~ s/([().?^\$])/\\$1/g;  # escape ().?^$
  $hostmask =~ s/\*/.*/g;             # translate wildchar "*" to regexp equivalent ".*"

  return $hostmask;
}


sub exec_command {
  my $command = shift;
  my $args = shift;
  my $pid;
  my @output;

  die "Can't fork: $!" unless defined($pid = open(KID, "-|"));

  if($pid) {
    # parent
    @output = <KID>;
    close KID;
    chomp @output;
    return @output;
  } else {
    # kid
    # Send stderr to stdout, so the bot will report errors back to the user
    $ENV{TERM} = '';
    open (STDERR, ">&STDOUT") or die "Can't dup stdout: $!\n";
    exec $command, split(' ', $args) or die "Can't exec $command: $!\n";
  }
}

1;
