#!/usr/bin/perl

# Perlbot (name needs to be changed...)
#
# Simple IRC bot for maintaining channels, passing notes,
# eventually network bridging (hopefully... [nope, that's scratched now :] )

use Carp;
use Net::IRC;
use strict;

use User;
use Chan;
use Network;
use Perlbot;
use PerlbotCore;

$starttime = time();

# from Perlbot.pm
$debug = $ENV{PERLBOT_DEBUG};

if($^O =~ /mac/i) {
  $dirsep = ':';
} else {
  $dirsep = '/';
}

my $irc;
my $pid;

# from Perlbot.pm
$VERSION = '1.5.1';
$AUTHORS = 'jmuhlich@bitflood.org / burke@bitflood.org';

# Let the user specify a config file as the first command line param, or
# default to 'config'.
$PerlbotCore::CONFIG = ($ARGV[0] ? $ARGV[0] : 'config');
if (! -f $PerlbotCore::CONFIG) {
  print "Config file '$PerlbotCore::CONFIG' not found\n";
  if ($PerlbotCore::CONFIG eq 'config') {
    print "\nPerhaps you haven't read the README.\n";
    print "Please read documentation/manual.txt before running perlbot.\n\n";
  }
  exit;
}
&PerlbotCore::parse_main_config;

$irc = new Net::IRC;

my $i = 0;
while(!$Perlbot::main_conn) {

  if($i > $#servers) {
    print "Could not connect to any of the specified servers! (Exiting)\n";
    exit;
  }

  $Perlbot::main_conn =
      $irc->newconn(Nick => $nicks[0],
		    Server => $servers[$i]->[0],
		    Port => $servers[$i]->[1],
		    Ircname => $ircname);
  $i++;
}

# Add the core functionality 'plugin' as the first plugin.  We have to stick
# it in @plugins like this because the plugin loading code won't find it since
# it's not under $plugindir and not called XXX::Plugin.  Also, load_plugins
# won't 'use' if we just push it on @plugins, it so we had to do that above.
push @plugins, 'PerlbotCore';
# attempt to load plugins and register their handlers
&load_plugins;

$pid = $$;

$SIG{INT} = \&sigint_handler;
$SIG{HUP} = \&sighup_handler;
$SIG{__DIE__} = \&sigdie_handler;

$irc->start;

die "Net::IRC event loop exited unexpectedly!";

exit(0);

#=================================================================

sub load_plugins {
    push @INC, $plugindir;
    opendir(PDH, $plugindir);
    DIR: foreach (readdir(PDH)) {
	# ignore '.' and '..' silently
	if (/\.\.?/) {
	    next DIR;
	}
	# make sure this plugin isn't in @noload.
	# I hate to do it like this, but grep() was losing for some reason...
	foreach my $nl (@PerlbotCore::noload) {
	    if (lc($_) eq lc($nl)) {
		print "Skipping '$_': noload\n" if $debug;
		next DIR;
	    }
	}
	validate_plugin($_) or next DIR;
	load_one_plugin($_) or next DIR;
    }

    # enable all the handlers for each plugin
    foreach (@plugins) {
	start_plugin($_);
    }
    closedir(PDH);
}

sub sigint_handler {
  # If no connection is passed to shutdown_bot, we interpret that to mean it
  # was called from the sigint handler. (It's a little dirty, but oh well.  :)
  shutdown_bot();
}

sub sighup_handler {
  # this should have been the default behavoir all along, but we were bad
  # about handling signals... :<
  &PerlbotCore::parse_main_config;
}

sub sigdie_handler {
  open CRASHLOG, ">>$crashlog" or warn "Could not open crashlog '$crashlog' for writing: $!";
  print CRASHLOG "Died with: $_[0]\n\n", Carp::longmess(), "\n=====\n\n\n";
  close CRASHLOG;
}

