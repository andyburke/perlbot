package Perlbot;

use 5.8.0;

use strict;
require Net::IRC;
use Data::Dumper;
use Symbol;

use Perlbot::Utils;
use Perlbot::Config;
use Perlbot::User;
use Perlbot::Channel;
use Perlbot::Logs;

our $VERSION = '1.9.7';
our $AUTHORS = 'burke@bitflood.org / jmuhlich@bitflood.org';

use fields qw(starttime configfile config ircobject ircconn msg_queue webserver plugins handlers handlers_backup users channels logs curnick masterpid);

sub new {
  my $class = shift;
  my $configfile = shift; $configfile ||= './config.xml';

  my $self = fields::new($class);

  $self->starttime = time();
  $self->configfile = $configfile;
  $self->config = undef;
  $self->ircobject = undef;
  $self->ircconn = undef;
  $self->msg_queue = [];
  $self->webserver = undef;
  $self->plugins = [];
  $self->handlers = {};
  $self->handlers_backup = undef;
  $self->users = {};
  $self->channels = {};
  $self->logs = new Perlbot::Logs($self);
  $self->curnick = '';
  $self->masterpid = $$;

  # here we hook up signals to their handlers
  # INT shuts the bot down
  # HUP reloads the config
  # DIE will give us a dump of what happened into the crashlog

  $SIG{INT}  = sub { $self->shutdown('ctrl-c from console') };
  $SIG{TERM} = sub { $self->shutdown('killed') };
  $SIG{HUP}  = sub { $self->reload_config };
  $SIG{__DIE__} = sub { $self->sigdie_handler(@_) };

  return $self;
}

# This sub provides programmatic access to our object's variables
# If someone tries to call a function that the perl interpreter
# doesn't find, it tries this function.

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $Perlbot::AUTOLOAD;

  $field =~ s/.*:://;

  if(!exists($Perlbot::FIELDS{$field})) {
    die "AUTOLOAD: no such method/field '$field'";
  }

  debug("Got call for field: $field", 15);

  $self->{$field};
}

# starts everything rolling...
sub start {
  my $self = shift;

  # this reads our config and puts it into $self->config
  $self->config = new Perlbot::Config($self->configfile);
  if (!$self->config) {
    print "Couldn't read main config file '" . $self->configfile . "'\n";
    exit -1;
  }

  # this will pull some stuff out of our config and create
  # appropriate objects in the bot
  $self->process_config;

  # config file must at the very least define a bot section and a server
  if (! $self->config->exists('bot')) {
    print "No bot section in config file '" . $self->{configfile} . "'\n";
    exit -1;
  }
  if (! $self->config->exists('server')) {
    print "No servers specified in config file '" . $self->configfile . "'\n";
    exit -1;
  }

  # here we loop over our defined servers attempting to connect.  we pause
  # after trying all the servers, before trying the first one again.
  my $i = 0;
  while (!$self->connect($i)) {
    $i++;
    if ($i >= $self->config->array_get('server')) {
      debug("server list exhausted; sleeping and trying again");
      $i = 0;
      sleep 5;
    }
  }

  # once we've connected, we load our plugins
  $self->load_all_plugins;

  # we should be all set, so we start the irc loop
  $self->ircobject->start();
}

# shuts the bot down gracefully
sub shutdown {
  my ($self, $quitmsg, $is_crash) = @_;

  debug("Shutting down...") if $$ == $self->masterpid;

  # make sure no handlers are triggered while we do this
  $self->handlers = {};  

  debug("Flushing output queue (this may take a moment)...");
  $self->empty_queue;

  # if this isn't the master process, just silently exit.
  if ($$ != $self->masterpid) {
    $self->ircconn->{_connected} = 0;
    $self->channels = undef; # !!! ?
    exit;
  }

  $quitmsg ||= 'goodbye';

  # we sign off of irc here
  debug("Disconnecting from IRC...");
  $self->ircconn->quit($quitmsg) if $self->ircconn;

  # we go through and call shutdown on each of our plugins
  debug("Unloading all plugins...");
  my @plugins_copy = @{$self->plugins};
  foreach my $plugin (@plugins_copy) {
    $self->unload_plugin($plugin->name);
  }

  # make our Channels get GC'd
  debug("Removing channel objects...");
  $self->channels = undef;

  # save out our in-memory config file
  $self->config->save if !$is_crash;

  # sleep a couple seconds to let everything fall apart
  debug("Sleeping 2 seconds...");
  sleep 2;

  # actually exit
  debug("Exiting");
  exit 0;
}

sub sigdie_handler {
  my $self = shift;
  my ($diemsg) = @_;
  my $dietime = time();

  # if not called from an eval()
  if (! $^S) {
    # prevent infinite loops, if this code or the shutdown code die()s
    $SIG{__DIE__} = 'DEFAULT';

    $diemsg ||= '(no message)';

    print localtime($dietime) . "\n\nDied with: $diemsg\n\n", Carp::longmess(), "\n=====\n\n\n";


    my $filename = File::Spec->catfile($self->config->get(bot => 'crashlogdir') ||
                                         File::Spec->curdir,
                                       'crashlog');
    open CRASHLOG, ">>$filename"
      or warn "Could not open crashlog '$filename' for writing: $!";
    print CRASHLOG localtime($dietime) . "\n\nDied with: $diemsg\n\n", Carp::longmess(), "\n=====\n\n\n";
    close CRASHLOG;

    $self->shutdown(' CRASHED :[ ', 1);
  }
}

sub reload_config {
  my $self = shift;

  # pretty simple, just overwrites our in-memory config with one
  # from disk
  debug("*** RELOADING CONFIG ***");
  $self->config->load;
}

# this steps through the config, creating objects when appropriate
sub process_config {
  my $self = shift;

  # make sure our users and channels are wiped, this is for when
  # we try to do config reloading.
  $self->users = {};
  $self->channels = {};

  # if there are users defined
  #   foreach user
  #     create a user object inside the bot object

  if ($self->config->exists('user')) {
    foreach my $user ($self->config->hash_keys('user')) {
      debug("loading user '$user'");
      $self->users->{$user} = new Perlbot::User($user, $self->config);
    }
  }

  # if there are channels defined
  #   foreach channel
  #     create a channel object
  #     foreach op listed in the config
  #       add them as an op if they exist as a user
  #     put the channel into the bot object

  if ($self->config->exists('channel')) {
    foreach my $channel ($self->config->hash_keys('channel')) {
      $channel = normalize_channel($channel);
      debug("loading channel '$channel'");
      my $chan = new Perlbot::Channel($channel, $self->config, $self);
      $self->channels->{$channel} = $chan;
    }
  }
}


# connects the bot to irc, takes an index into the list of servers
sub connect {
  my $self = shift;
  my $index = shift;
  $index ||= 0;

  my $server;
  my $port;
  my $password;
  my $nick;
  my $ircname;
  my $localaddr;
  my $username;
  my $ssl;
  my $pacing;

  my $handlers;

  # make an ircobject if one doesn't exist yet
  if (!$self->ircobject) {
    $self->ircobject = new Net::IRC;
    debug( sub { $self->ircobject->{_debug} = 1; }, 10);
  }

  # if we already have a connection, back up our handlers
  if ($self->ircconn) { # had a connection
    $self->handlers_backup = $self->ircconn->{_handler};
  }

  # if the server we've been given exists
  #   set all our variables
  #   set our ircconn object to the new one

  if ($self->config->exists(server => $index)) {
    $server    = $self->config->get(server => $index => 'address');
    $port      = $self->config->get(server => $index => 'port');
    $password  = $self->config->get(server => $index => 'password');
    $ssl       = $self->config->get(server => $index => 'ssl');
    $pacing    = $self->config->get(server => $index => 'pacing');
    $nick      = $self->config->get(bot => 'nick');
    $ircname   = $self->config->get(bot => 'ircname');
    $localaddr = $self->config->get(bot => 'localaddr');
    $username  = $self->config->get(bot => 'username');

    $port ||= 6667;
    $password ||= '';
    $nick ||= 'perlbot';
    $ircname ||= 'imabot';
    $localaddr ||= '';
    $username ||= '';
    $ssl ||= 0;
    $pacing ||= 0;

    debug("attempting to connect to server $index: $server");

    $self->ircconn =
        $self->ircobject->newconn(Nick => $nick,
                                  Server => $server,
                                  Port => $port,
                                  Password => $password,
                                  Ircname => $ircname,
                                  LocalAddr => $localaddr,
                                  Username => $username,
                                  SSL => $ssl,
                                  Pacing => $pacing,
                                  );
  }
  
  # if our connection exists and it's actually connected
  #   if we had a backup of our handlers, jam it into this ircconn
  #   set our curnick appropriately
  #   ignore any hostmasks specified in the config
  #   return the connection
  # else fail

  if ($self->ircconn && $self->ircconn->connected()) {
    debug("connected to server: $server");

    if(defined($self->handlers_backup)) {
      debug("reusing old handlers for new connection", 5);
      $self->ircconn->{_handler} = $self->handlers_backup;
      $self->handlers_backup = undef;
    }

    $self->curnick = $nick;

    if ($self->config->exists(bot => 'ignore')) {
      foreach my $hostmask ($self->config->array_get(bot => 'ignore')) {
        $self->ircconn->ignore('all', $hostmask);
      }
    }

    return $self->ircconn;
  } else {
    return undef;
  }
}

# loads all our plugins
sub load_all_plugins {
  my $self = shift;

  my @plugins;
  my @plugins_found = $self->find_plugins;

  # if there are noload entries
  #   foreach plugin
  #     if it's listed in @noload
  #       print debug message, but do nothing else
  #     else
  #       push it onto our list of plugins to load

  if ($self->config->exists(bot => 'noload')) {
    foreach my $plugin (@plugins_found) {
      if (grep {lc($plugin) eq lc($_)} $self->config->array_get(bot => 'noload')) {
        debug("Skipping '$plugin': noload");
      } else {
        push @plugins, $plugin;
      }
    }
  }

  # foreach plugin
  #   load plugin

  foreach my $plugin (@plugins) {
    $self->load_plugin($plugin);
  }
}

# Looks for all plugins on disk in all plugindirs, doing some basic
# sanity checks (making sure the plugin perl module file exists).
sub find_plugins {
  my ($self) = @_;
  my @found_plugins;

  # foreach plugindir specified in the config
  #   open dir
  #   foreach directory in the open dir (should be a plugin dir)
  #     if it's '.' or '..'
  #       skip
  #     set our dirname to the right thing
  #     if it's not really a directory
  #       skip
  #     set our plugin name correctly
  #     if it's not there
  #       skip
  #     add this plugin to our list of found plugins
  #     add it's directory to @INC so we can use it later
  #     close the dir
  #   return our found plugins

  foreach my $plugindir ($self->config->array_get(bot => 'plugindir')) {
    opendir(PDH, $plugindir);
    foreach my $plugin (readdir(PDH)) {
      # ignore '.' and '..' silently
      if ($plugin eq '.' or $plugin eq '..') {
        next;
      }
      # ignore non-existent plugin subdirs
      my $dir = File::Spec->catdir($plugindir, $plugin);
      if (! -d $dir) {
        debug("Ignoring '$plugin': $dir is not a directory");
        next;
      }
      # ignore subdirs without a Plugin.pm
      my $module = File::Spec->catfile($dir, "${plugin}.pm");
      if (! -f $module) {
        debug("Ignoring '$plugin': no ${plugin}.pm in $dir");
        next;
      }

      # success!
      debug("Found '$plugin'");
      push @found_plugins, $plugin;
      if(!grep(/$dir/, @INC)) { push @INC, $dir; }
    }
    closedir(PDH);
  }

  return @found_plugins;
}

# Tries to load a plugin
# params:
#   1) name of plugin to load
# returns:
#   0 if load failed
#   reference to plugin object if load succeeded
sub load_plugin {
  my ($self, $plugin) = @_;

  debug("loading plugin '$plugin'");
  # make sure the plugin isn't already loaded
  if (grep {$plugin eq $_->name} @{$self->plugins}) {
    debug("plugin '$plugin' already loaded!");
    return 0;
  }
  # try to import the plugin's package
  eval "local \$SIG{__DIE__}='DEFAULT'; require ${plugin}";
  # check for module load error
  if ($@) {
    debug("  failed to load '$plugin': $@");
    return 0;
  }
  # determine path to plugin subdirectory
  my $pluginfile = $INC{"$plugin.pm"};
  my (undef,$pluginpath,undef) = File::Spec->splitpath($pluginfile);
  $pluginpath = File::Spec->canonpath($pluginpath);
  my $pluginref = eval "local \$SIG{__DIE__}='DEFAULT'; new Perlbot::Plugin::${plugin}(\$self, \$pluginpath)";
  # check for constructor error
  if ($@ or !$pluginref) {
    debug("  failed construction of '$plugin': $@");
    return 0;
  }

  # see if the plugin needs to put stuff in the main config
  if(!$self->config->exists(plugin => $plugin)) {
    $self->config->exists('plugin') or $self->config->hash_initialize('plugin');
    $self->config->exists(plugin => $plugin) or $self->config->hash_initialize(plugin => $plugin);
    $pluginref->set_initial_config_values() or $self->config->hash_delete(plugin => $plugin);
  }

  # call init on the plugin
  $pluginref->init;
  # push it into the bot's internal list
  push @{$self->plugins}, $pluginref;
  # return the pluginref as our true value (meaning success)
  return $pluginref;
}


sub unload_plugin {
  my ($self, $plugin) = @_;
  my ($pluginref);

  debug("unloading plugin: $plugin");
  ($pluginref) = grep {$plugin eq $_->name} @{$self->plugins};
  if (!$pluginref) {
    debug("plugin '$plugin' not loaded!");
    return 0;
  }

  @{$self->plugins} = grep {$pluginref ne $_} @{$self->plugins};
  $pluginref->_shutdown;

  # Here we try to make perl forget about the plugin module entirely.  It's
  # hard to say what's actually necessary here and what's superfluous.  If
  # you see this, and you have Knowledge in this area, contact the authors
  # or the mailing list.  Until then, this seems to work OK.
  # (does it leak memory???)
  undef $pluginref;                     # heh, a rhyme
  $self->remove_all_handlers($plugin);  # unhook it from the bot's multiplexer
  $self->webserver_remove_all_handlers($plugin); # unhook it from the webserver
  eval "no ${plugin}";                  # first step of unloading (necessary?)
  Symbol::delete_package("Perlbot::Plugin::${plugin}"); # delete all symbols
  delete $INC{"$plugin.pm"};            # force full reload on next 'require'

  return 1;
}


sub reload_plugin {
  my ($self, $plugin) = @_;

  # \q used instead of " so emacs doesn't get confused.
  $self->unload_plugin($plugin) or return \q{unload};
  $self->load_plugin($plugin) or return \q{load};

  return 1;
}


# This works just like $conn->add_handler but you need to pass the
# plugin name too
# params:
#   1) event type (string or numeric)
#   2) a code ref to be executed
#   3) the name of the plugin that the code ref came from
sub add_handler {
  my $self = shift;
  my ($event, $coderef, $plugin) = @_;

  # if no one has hooked this event yet
  #   make sure we have a hashref for the event type in the bot object
  #   add a hook for this event type to the ircconn, point it to our multiplexer

  unless ($self->handlers->{$event}) {
    debug("    event:$event plugin:$plugin", 4);
    $self->handlers->{$event} = {};
    $self->ircconn->add_handler($event, sub { $self->event_multiplexer(@_) });
  }

  # add this handler to the bot's internal handlers

  $self->handlers->{$event}{$plugin} = $coderef;
}

# Removes the handler for one event type for a given plugin
# params:
#   1) event type (same as param 1 to add_handler)
#   2) plugin name
sub remove_handler {
  my $self = shift;
  my ($event, $plugin) = @_;

  # if the bot knows about at least one handler for this event type
  #   if the given plugin has actually registered a callback for this type
  #     delete that callback

  debug("    event:$event plugin:$plugin", 4);
  if ($self->handlers->{$event}) {
    if ($self->handlers->{$event}{$plugin}) {
      delete $self->handlers->{$event}{$plugin};
    }
  }
  # Net::IRC doesn't provide handler removal functionality, so there's
  # nothing more to do here.
}

# Removes all handlers for a given plugin
# params:
#   1) plugin name
sub remove_all_handlers {
  my $self = shift;
  my ($plugin) = @_;

  # Iterate over every event we're handling, and try to remove $plugin's
  # handler for that event.  If $plugin doesn't handle an event,
  # remove_handler just silently fails.
  foreach my $event (keys %{$self->handlers}) {
    $self->remove_handler($event, $plugin);
  }
}

sub event_multiplexer {
  my $self = shift;
  my $conn = shift;
  my $event = shift;
  my $text = $event->{args}[0];
  my $user = $self->get_user($event->{from});

  # foreach plugin that handles this type of event
  #   if we really have a coderef for this plugin/event type
  #     get the coderef
  #     call the coderef with the event, a user we looked up and the event text
  #   else
  #     do nothing

  debug("Got event '" . $event->type . "'", 4);
  foreach my $plugin (keys(%{$self->handlers->{$event->type}})) {
    if (exists($self->handlers->{$event->type}{$plugin})) {
      debug("  -> dispatching to '$plugin'", 5);
      my $handler = $self->handlers->{$event->type}{$plugin};
      &$handler($event, $user, $text);
    } else {
      # If we get here, we must have already processed an unload
      # request for this plugin in the core handler, so we need
      # to be careful to skip it here!
      debug("  -> '$plugin' unloaded -- skipping", 5);
    }
  }

}

sub webserver_add_handler {
  my $self = shift;

  debug("adding handler: " . join(', ', @_), 4);

  if (!$self->webserver) {
    # start up the webserver
    debug('Automatically starting web service');

    eval 'use Perlbot::WebServer';
    if ($@) {
      debug("Could not load WebServer module: $@");
      return undef;
    }

    $self->webserver = Perlbot::WebServer->new($self);
    if (!$self->webserver->start) {
      debug('Could not start internal web service!');
      return undef;
    }
  }

  # pass all params as given
  return $self->webserver->hook(@_);
}

# unhooks every web path hooked by a given plugin
sub webserver_remove_all_handlers {
  my $self = shift;
  my $ret;

  debug("removing plugin handlers: " . join(', ', @_), 4);

  if (!$self->webserver) {
    return undef;
  }

  # pass all params as given
  $ret = $self->webserver->unhook_all(@_);

  my $num_hooks = $self->webserver->num_hooks;
  if ($num_hooks == 0) {
    # shut down the webserver
    debug('Automatically stopping web service');
    $self->webserver->shutdown();
    $self->webserver = undef;
  } else {
    debug("Still $num_hooks web hooks left", 4);
  }

  return $ret;
}

# removes all handlers and sends all waiting events, used prior to shutdown
sub empty_queue {
  my ($self) = @_;

  debug("outputing " . $self->ircobject->queue . " events...", 3);
  use Data::Dumper;
  print Dumper $self->ircobject->queue;
  while ($self->ircobject->queue) {
    $self->ircobject->do_one_loop;
  }
}

# takes a username or hostmask and returns a user if one exists that matches
sub get_user {
  my $self = shift;
  my $param = shift;
  my @tempusers;

  # first check to see if $param matches a username
  if (exists $self->users->{$param}) {
    return $self->users->{$param};
  }

  # foreach user
  #   foreach of their configured hostmasks
  #     if the given hostmask matches their configured one
  #       push them onto the list of matching users
  #       go back to the foreach user loop

  foreach my $user (values %{$self->users}) {
    my @hostmasks = ($user->hostmasks, @{$user->temphostmasks});
    foreach my $tempmask (@hostmasks) {
      my $regex = hostmask_to_regexp($tempmask);
      if ($param =~ /^$regex$/i) {
        push(@tempusers, $user);
        last;
      }
    }
  }

  # if we only got one user
  #   return that user
  # else if we got MORE than one user
  #   print out some debugging to alert the admin
  # return nothing, ie: if we got here, there's no matching user

  if (@tempusers == 1) {
    return $tempusers[0];
  } elsif (@tempusers > 1) {
    debug("Multiple users matched $param !");
    debug(\@tempusers);
  }

  return undef;

}

######################################
# functions for maintaining our admins

sub is_admin {
  my $self = shift;
  my $user = shift;

  return grep({$_ eq $user->name} $self->config->array_get(bot => 'admin')) ? 1 : 0;
}

sub add_admin {
  my $self = shift;
  my $user = shift;

  $self->config->array_push(bot => 'admin', $user->name);
}

sub remove_admin {
  my $self = shift;
  my $user = shift;

  $self->config->array_delete(bot => 'admin', $user->name);
}


# some utility functions

sub uptime {
  my $self = shift;

  return time() - $self->starttime();
}

sub humanreadableuptime {
  my $self = shift;

  my $uptime = time() - $self->starttime();
  my $uptimedays = sprintf("%02d", $uptime / 86400);
  $uptime = $uptime % 86400;
  my $uptimehours = sprintf("%02d", $uptime / 3600);
  $uptime = $uptime % 3600;
  my $uptimeminutes = sprintf("%02d", $uptime / 60);
  $uptime = $uptime % 60;
  my $uptimeseconds = sprintf("%02d", $uptime);

  return "${uptimedays}d:${uptimehours}h:${uptimeminutes}m:${uptimeseconds}s";

}

# send a msg to a nick or channel
sub msg {
  my $self = shift;
  my $target = shift;
  my $text = shift;

  $self->ircconn->privmsg($target, $text);
  
}

sub notice {
  my $self = shift;
  my $target = shift;
  my $text = shift;

  $self->ircconn->notice($target, $text);
}

sub op {
  my $self = shift;
  my $channel = shift;
  my $target = shift;

  $self->ircconn->mode($channel, '+o', $target);
}

sub deop {
  my $self = shift;
  my $channel = shift;
  my $target = shift;

  $self->ircconn->mode($channel, '-o', $target);
}

sub nick {
  my $self = shift;
  my $nick = shift;

  $self->curnick = $nick;
  $self->ircconn->nick($nick);
  return $self->curnick;
}

sub whois {
  my $self = shift;
  my $target = shift;

  $self->ircconn->whois($target);
}

sub dcc_send {
  my $self = shift;
  my $nick = shift;
  my $filename = shift;

  $self->ircconn->new_send($nick, $filename);
}

sub dcc_chat {
  my $self = shift;
  my $nick = shift;
  my $host = shift;

  $self->ircconn->new_chat(1, $nick, $host);
}

sub mode {
  my $self = shift;
  my $channel = shift;
  my $modeline = shift;

  $self->ircconn->mode($channel, $modeline);
}

sub kick {
  my $self = shift;
  my $channel = shift;
  my $nick = shift;
  my $reason = shift;

  $self->ircconn->kick($channel, $nick, $reason);
}

sub schedule {
  my $self = shift;
  my $time = shift;
  my $coderef = shift;

  $self->ircconn->schedule($time, $coderef);
}

sub get_channel {
  my ($self, $channel) = @_;

  $channel = normalize_channel($channel);
  if (exists $self->channels->{$channel}) {
    return $self->channels->{$channel};
  } else {
    return undef;
  }
}

sub DESTROY {
  # dummy
}

1;









