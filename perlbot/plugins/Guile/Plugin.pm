# Joh Yong-iL <tolkien@nownuri.net>
# 19991004. first write.

package Guile::Plugin;

use vars qw(@Guile_io, $Guile_sel, $Guile_pid);
use Perlbot;
use POSIX;
use IPC::Open3;
use IO::Select;
use IO::Handle;

sub get_hooks {
  Guile_init();
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
  my $conn = shift;
  my $event = shift;
  my $who = $event->{to}[0];

  my $args = $event->{args}[0];
  if ($args =~ /^${pluginprefix}gl\s*/) {
    guile($conn, $event, $who);
  }

}

sub on_msg {
  my $conn = shift;
  my $event = shift;
  my $who = $event->nick;

  my $args = $event->{args}[0];
  if ($args =~ /^${pluginprefix}gl\s*/) {
    guile($conn, $event, $who);
  }
}

sub guile {
  my $conn = shift;
  my $event = shift;
  my $who = shift;

  if (!defined($pid = fork)) {
    $conn->privmsg($who, "error in guile, or something...");
    $conn->{_connected} = 0;
    exit 1;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...
    
    my ($args, $line, @bc);
    ($args = $event->{args}[0]) =~ s/^${pluginprefix}gl\s*//;
    $args =~ s/`//g;                  # remove security hole like !gl \"`ls`\"
    $args =~ s/(\s*quit\s*(\d*))//g;  # never use (quit)
    $args =~ s/(\s*exit\s*(\d*))//g;  # never use (exit)
  if ($args) {

    Guile_in($args);

    my $halt = 0;
    for(my $i=0; $i < 5; $i++) {
      ($halt, @bc) = Guile_out();
      if ($halt) { last; }
      ($halt, @bc) = Guile_err();
      if ($halt) { last; }
    }
    foreach $line (@bc) {
      $line =~ s/^guile> //;
      if ($line) { $conn->privmsg($who, $line); }
    }
  }

    $conn->{_connected} = 0;

    exit 0;
  }
}

sub Guile_in {
  my $args = shift;
  my (@ready, $fh, $line);

  @ready = $Guile_sel->can_write(1);
  foreach $fh (@ready) {
    if ($fh == $Guile_io[0]) {
      $fh->syswrite($args."\n", 1024);
    }
  }
}

sub Guile_out {
  my (@ready, $fh, $line, @bc, $ok);
  $ok = 0;

  @ready = $Guile_sel->can_read(1);
  foreach $fh (@ready) {
    if ($fh == $Guile_io[1]) {
      $ok = 1;
      $fh->sysread($line, 1024);
      @bc = split(/\n/, $line); 
    }
    if ($fh == $Guile_io[2]) {
      $ok = 2;
      $fh->sysread($line, 1024);
      push @bc, split(/\n/, $line); 
    }
  }
  return ($ok, @bc);
}

sub Guile_err {
  my (@ready, $fh, $line, @bc, $ok);
  $ok = 0;

  print "Guile: ERR\n" if $debug;
  @ready = $Guile_sel->has_error(1);
  foreach $fh (@ready) {
    if ($fh == $Guile_io[2]) {
      $ok = 1;
      $fh->sysread($line, 1024);
      @bc = split(/\n/, $line); 
  @ready = $Guile_sel->can_write(1);
  foreach $fh (@ready) {
    if ($fh == $Guile_io[0]) {
      my $re = $Guile_io[0]->eof();
      $fh->syswrite($re, 10);
    }
  }
    }
  }
  return ($ok, @bc);
}

sub Guile_init {
  $Guile_io[0] = new IO::Handle;
  $Guile_io[1] = new IO::Handle;
  $Guile_io[2] = new IO::Handle;

  # open3(\*WTRFH, \*RDRFH, \*ERRFH, 'some cmd and args', 'optarg', ...);
  $Guile_pid = open3($Guile_io[0], $Guile_io[1], $Guile_io[2], 'guile');
  print "Guile: pid = $Guile_pid\n" if $debug;

  $Guile_sel = IO::Select->new();
  $Guile_sel->add($Guile_io[0]);
  $Guile_sel->add($Guile_io[1]);
  $Guile_sel->add($Guile_io[2]);

  my (@ready, $fh, $ln);
  sleep 1;
  @ready = $Guile_sel->can_read(1);
  foreach $fh (@ready) {
    if ($fh == $Guile_io[1]) {
      $fh->sysread($ln, 1024);
      print "Guile: guile output = $ln\n" if $debug;
    }
  }
}

1;
