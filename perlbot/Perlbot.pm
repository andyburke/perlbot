package Perlbot;

# This package serves as a place to store all the globals for the bot.
# It exports all the symbols in it by default.  A plugin can do
# 'use Perlbot' to have these symbols exported into its own namespace,
# so the plugin could say, for example, '$users{$nick}'.  Or it could do
# 'use Perlbot ()', and not have them exported (but it could still say
# '$Perlbot::users{$nick}').
#
# Any separate utilities for perlbot (such as the planned config file
# editor) can 'use' this package to get access to all the utility subs
# here, such as parse_config and to_channel.

use strict;
use vars qw(
	    @ISA @EXPORT
	    $VERSION $AUTHORS
	    $debug
	    $dirsep
	    $plugindir $main_conn
            $crashlog
            $ircname
            $currentnick
            $commandprefix $pluginprefix
	    @plugins @servers @nicks
	    %handlers %users %channels
	    );
require Exporter;

@ISA = qw(Exporter);

# symbols to export
@EXPORT = qw(
	     $VERSION $AUTHORS
	     $debug
	     $plugindir
	     $dirsep
             $crashlog
             $ircname
             $currentnick
             $commandprefix $pluginprefix
	     @plugins @servers @nicks
	     %handlers %users %channels
	     &parse_config &write_config
	     &notify_users &to_channel &from_channel
	     &host_to_user &username &update_user
	     &validate_plugin &load_one_plugin &start_plugin
	     &add_handler &unload_one_plugin
	     &shutdown_bot
	     );

# parses a config file and returns a struct holding all the data in the file
# Params:
#   1) filename of the file to parse
# Returns:
#   If there was an error :  an appropriate error string
#   If there was no error :  a hash ref
#   The hash stores arrays, those arrays store hashes, and those hashes store arrays.  :)
#   If this is the first user listed in your config file:
#     user {
#       name      billy
#       hostmask  billy*!*billy@*.billykins.org
#       hostmask  billy*!*william@billypc.someplace.com
#     }
#   then you could get the array of hostmasks with ($hashref is the value this sub returns):
#     @{$hashref->{'user'}[0]{'hostmask'}}
#   because you're looking for 'user' 0 (the first one listed in the config file) and you want
#   his 'hostmask'(s).
#   And here's the value of the name:
#     $hashref->{'user'}[0]{'name'}[0]
#   Look in parse_main_config to see how we handle it when dealing with the bot's main config
#   file.
sub parse_config {
  my $fname = shift;
  my $line = 1;
  my ($var, $rest);
  my $state = 0;
  my $class;
  my $err = 0;
  my $text;
  my $fields;
  my $bighash = {};
  
  open(CONFIG, "<$fname");
  foreach (<CONFIG>) {
    # remove leading and trailing whitespace (note: .*? is a non-greedy .*)
    s/^\s*(.*?)\s*$/$1/;
    # skip comments and blank lines
    unless (/^(?:\#.*)?$/) {
      $text = $_;
      if ($state == 0) {
	# get "class"
	if (($class) = /^(\w*)\s*\{\s*$/) {
	  print "begin class $class\n" if $debug;
	  if (!exists($bighash->{$class})) {
	    $bighash->{$class} = [];
	  }
	  $fields = {};
	  push @{$bighash->{$class}}, $fields;
	  $state = 1;
	} else { $err = 1; last; }
      } else {
	if (/^\}$/) {
	  print "end class $class\n" if $debug;
	  # unlink $fields from the hash ref we were using, just in case...?
	  $fields = undef;
	  $state = 0;
	} elsif (($var, $rest) = /^(\w*)\s*(.*)$/) {
	  print "  $var: $rest\n" if $debug;
	  if (!exists($fields->{$var})) {
	    # if it's a new var, create a new array ref
	    $fields->{$var} = [$rest];
	  } else {
	    # if we've seen this var before, just push the val
	    push(@{$fields->{$var}}, $rest);
	  }
	} else { $err = 1; last; }
      }
    }
    $line++;
  }
  close(CONFIG);
  
  if ($err) {
    return "syntax error in $fname at line $line: $text";
  } else {
    return $bighash;
  }
  
}

# writes a config file to disk
# Params:
#   1) filename of the file to write
#   2) config structure, as returned by parse_config (see above)
# Returns:
#   If there was an error :  an appropriate error string
#   If there was no error :  undef
sub write_config {
  my ($fname, $bighash) = @_;
  my $line = 1;
  my ($var, $rest);
  my $state = 0;
  my $class;
  my $err = 0;
  my $text;
  my $fields;
  
  open(CONFIG, ">$fname") or $err = $_;
  foreach my $class (keys(%{$bighash})) {
    print CONFIG "\n###############################\n";
    print CONFIG "# $class objects\n";
    print CONFIG "###############################\n\n";
    foreach my $object (@{$bighash->{$class}}) {
      print CONFIG "$class {\n";
      foreach my $fieldname (keys(%{$object})) {
	foreach my $fieldvalue (@{$object->{$fieldname}}) {
	  print CONFIG "\t$fieldname\t\t$fieldvalue\n";
	}
      }
      print CONFIG "}\n\n";
    }
  }
  close(CONFIG);
  
  if ($err) {
    return "error writing to $fname: $text";
  } else {
    return undef;
  }
  
}

sub notify_users {
  my $priv_conn = shift;
  my ($type, $text) = (shift, shift);
  my ($sec,$min,$hour,$mday,$mon,$year);
  my $date;

  ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
  $year += 1900; #yay, y2k!
  $mon += 1;

  $date = sprintf('%d/%02d/%02d %02d:%02d:%02d', $year, $mon, $mday, $hour, $min, $sec);

  foreach (values(%users)) {
    if($_->{flags} =~ /w/ && ($_->{lastseen} ne 'never')) {
      $priv_conn->privmsg($_->{curnick}, "$date: $text") ;
    }
  }
}

sub to_channel {
  my $channel = shift;
  $channel = "#$channel" if $channel !~ /^[\#\&].*/;
  $channel =~ tr/\[\]\\/\{\}\|/;
  $channel =~ tr/[A-Z]/[a-z]/;
  return $channel;
}

sub from_channel {
  my $channel = shift;
  $channel =~ s/^[#&]//;
  return $channel;
}

sub host_to_user {
  my $realmask = shift;

  foreach (values(%users)) {
    foreach my $testmask (@{$_->{hostmasks}}) {
      return $_ if ($realmask =~ /$testmask/i);
    }
  }
  return undef;
}

sub username {
  my $user = shift;
  my $username;

  foreach my $tempname (keys(%users)) {
    if($user == $users{$tempname}) {
      $username = $tempname;
      last;
    }
  }

  return $username;
}

sub update_user {
  my $priv_conn = shift;
  my $nick = shift;
  my $host = shift;
  my $user = host_to_user($nick.'!'.$host);

  $priv_conn->whois($nick);

  if($user) {
    $user->{curnick} = $nick;
    $user->{lastseen} = time();

    if(!$user->{notified} && $user->notes >= 1) {
      my $numnotes = $user->notes;
      my $noteword = ($numnotes == 1) ? 'note' : 'notes';
      $priv_conn->privmsg($nick, "$numnotes $noteword stored for you.");
      $user->{notified} = 1;
    }
  }
  return $user;
}

# Checks to see if a given plugin exists (on disk)
# params:
#   1) name of plugin to check
# returns:
#   0 if plugin doesn't exist
#   1 if plugin exists
sub validate_plugin {
  my $pi = shift;
  if (! -d $plugindir . $dirsep . $pi) {
    print "Ignoring '$pi': $plugindir" . $dirsep . "$pi is not a directory\n" if $debug;
    return 0;
  }
  if(! -f $plugindir . $dirsep . $pi . $dirsep . 'Plugin.pm') {
    print "Ignoring '$pi': no Plugin.pm in $plugindir" . $dirsep . "$pi\n" if $debug;
    return 0;
  }
  return 1;
}

# Tries to load a plugin
# params:
#   1) name of plugin to load
# returns:
#   0 if load failed
#   1 if load succeeded
sub load_one_plugin {
  my $pi = shift;
  eval "require ${pi}::Plugin";  # try to import the plugin's package
  if ($@) {                      # if error...
    print $@ if $debug;
    return 0;
  }
  push @plugins, $pi;            # add plugin to our list
  return 1;
}

# Calls get_hooks and registers handlers
# params:
#   1) name of plugin to start
sub start_plugin {
  my $pi = shift;
  my $hooks = eval "${pi}::Plugin::get_hooks()";
  # for each event this plugin hooks, get the code ref and call
  # add_handler
  print "Starting '$pi': " if $debug;
  foreach my $event (keys(%$hooks)) {
    print "$event " if $debug;
    add_handler($event, $hooks->{$event}, $pi);
  }
  print "\n" if $debug;
}

# Tries to unload a plugin
# params:
#   1) name of plugin to unload
# returns:
#   0 if unload failed
#   1 if unload succeeded
sub unload_one_plugin {
  my $pi = shift;
  return if $pi eq 'PerlbotCore';
  print "Stopping '$pi'\n" if $debug;
  remove_handlers($pi);
  eval "no ${pi}::Plugin";             # try to unload the plugin's package
  if ($@) {                            # if error...
    print $@ if $debug;
    return 0;
  }
  # remove plugin from %INC, to force it to be read from disk if it gets reloaded
  delete $INC{$pi.$dirsep.'Plugin.pm'};
  # grab all the OTHER plugins... the ones to keep
  @plugins = grep {!/^\Q$pi\E$/} @plugins;
  return 1;
}

# This works just like $conn->add_handler but you need to pass the
# plugin name too
# params:
#   1) event type (string or numeric)
#   2) a code ref to be executed
#   3) the name of the plugin that the code ref came from
sub add_handler {
  my ($event, $coderef, $plugin) = @_;

  # do some init stuff if nobody has hooked this event yet
  unless ($handlers{$event}) {
    $handlers{$event} = {};                    # create the hash ref
    # add our 'multiplexer' sub as the handler
    $main_conn->add_handler($event, \&handle_everything);
  }
  $handlers{$event}->{$plugin} = $coderef;       # store the code ref
}

# Removes all handlers for a given plugin
# params:
#   1) plugin name
sub remove_handlers {
  my ($plugin) = @_;

  # loop over all the hash refs that store the code refs
  foreach my $ref (values(%handlers)) {
    delete $ref->{$plugin};
  }
}

# Shuts down the bot completely
# params:
#   1) connection object, or none if the shutdown was requested by
#      a ctrl-c at the console (sigint)
#   2) (optional) a quit message
# The idea of passing an undef'd connection to mean ctrl-c was
# pressed seems pretty hackish.  The connection really shouldn't even
# matter since the bot never has more then one connection object.
# Maybe this could be cleaned up sometime.
sub shutdown_bot {
  my ($conn, $quitmsg) = (shift, shift);

  # if no conn is passed, we're being called from the sigint handler
  if (!$conn) {
    $conn = $main_conn;
    notify_users($conn, 'quit', '<CONSOLE> requested QUIT via ctrl-c');
  }

  $conn->quit($quitmsg);
  my @plugins_copy = @plugins;
  foreach my $plugin (@plugins_copy) {
    unload_one_plugin($plugin);
  }
  # MacOS doesn't implement wait, so let's avoid a warning
  if($^O !~ /mac/i) {
    print "Waiting for child processes to exit...\n" if $debug;
    wait;
  }
  print "Sleeping 2 seconds...\n" if $debug;
  sleep 2;
  print "Exiting\n" if $debug;
  exit 0;
}



# PRIVATE
# This sub handles ALL events from Net::IRC and calls the appropriate handlers
#   from %handlers, in whatever order the hash returns them
# Params:
#   1) a Net::IRC::Connection object for the connection the event came from
#   2) a Net::IRC::Event object for the event we're handling
sub handle_everything {
  my $conn = shift;
  my $event = shift;

  $| = 1;
  foreach my $plug (keys(%{$handlers{$event->type}})) {
    if ($debug == 2) { print "handle $plug:".$event->type."\n" }
    if (exists($handlers{$event->type}->{$plug})) {
      my $handler = $handlers{$event->type}->{$plug};
      &$handler($conn, $event);
    } else {
      # If we get here, we must have already processed an unload
      # request for this plugin in the core handler, so we need
      # to be careful to skip it here!
      if ($debug == 2) { print "  (unloaded; skipping)\n" }
    }
  }

  #foreach my $handler (values(%{$handlers{$event->type}})) {
  #  &$handler($conn, $event);
  #}
}


1;
