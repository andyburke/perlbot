package Perlbot::Utils;

use strict;

use File::Spec;
use XML::Simple;

use vars qw(
            @ISA @EXPORT
            $DEBUG
            );
require Exporter;

@ISA = qw(Exporter);

# symbols to export
@EXPORT = qw(
             $DEBUG
             &read_generic_config &write_generic_config
             &normalize_channel &strip_channel
             &validate_hostmask
             &exec_command
          );


$DEBUG = $ENV{PERLBOT_DEBUG};
$DEBUG ||= 0;

sub read_generic_config {
  my ($filename) = @_;

  return XMLin($filename,
               forcearray => 1);
}

sub write_generic_config {
  my ($filename, $hashref) = @_;

  ($filename && $hashref) or return 0;

  my $xml = XMLout($hashref,
                   rootname => 'config');
  open(CONFIG, ">$filename");
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
    print "validate_hostmask: '$hostmask' has bad syntax\n" if $DEBUG;
    return undef;
  }
  if ($hostmask =~ /!\*@/ or $hostmask =~ /@[\*\.]*$/) {
    print "validate_hostmask: '$hostmask' is an open hostmask (insecure)\n" if $DEBUG;
    return undef;
  }
  return 1;
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
