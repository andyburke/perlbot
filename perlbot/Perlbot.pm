package Perlbot;

use Net::IRC;
use Data::Dumper;

use Perlbot::Utils;
use Perlbot::Config;
use Perlbot::User;
use Perlbot::Chan;

$VERSION = '1.9.0';
$AUTHORS = 'burke@bitflood.org / jmuhlich@bitflood.org';

sub new {
  my $class = shift;
  my $configfile = shift; $configfile ||= './config';

  my $self = {
    starttime => time(),
    configfile => $configfile,
    config => undef,
    ircobject => undef,
    ircconn => undef,
    msg_queue => [],
    empty_queue => 1,
    plugins => [],
    handlers => {},
    users => {},
    channels => {},
    curnick => ''
  };

  bless $self, $class;

  $SIG{INT} = sub { $self->shutdown('ctrl-c from console') };
  $SIG{HUP} = sub { $self->reload_config };

  return $self;
}

# starts everything rolling...
sub start {
  my $self = shift;

  # this reads our config and puts it into $self->{config}
  $self->{config} = new Perlbot::Config($self->{configfile})
      or die "Couldn't read main config file '$self->{configfile}'\n";

  # this will pull some stuff out of our config and create
  # appropriate objects in the bot
  $self->process_config;

  # config file must at the very least define a bot section and a server
  $self->config->value('bot')
      or die "No bot section in config file '$self->{configfile}'\n";
  $self->config->value('server')
      or die "No servers specified in config file '$self->{configfile}'\n";
  
  # here we loop over our defined servers attempting to connect.  we pause
  # after trying all the servers, before trying the first one again.
  my $i = 0;
  while (!$self->connect($i)) {
    $i++;
    if ($i >= @{$self->config->value('server')}) {
      print "connect: server list exhausted; sleeping and trying again\n" if $DEBUG;
      $i = 0;
      sleep 5;
    }
  }

  # once we've connected, we load our plugins
  $self->load_all_plugins;

  # we should be all set, so we start the irc loop
  $self->{ircobject}->start();
}

# shuts the bot down gracefully
sub shutdown {
  my ($self, $quitmsg) = @_;

  print "Shutting down...\n" if $DEBUG;

  $quitmsg ||= 'goodbye';

  # we sign off of irc here
  $self->{ircconn}->quit($quitmsg);

  # we go through and call shutdown on each of our plugins
  my @plugins_copy = $self->plugins;
  foreach my $plugin (@plugins_copy) {
    $plugin->shutdown;
  }

  # save out our in-memory config file
  $self->config->write;

  # sleep a couple seconds to let everything fall apart
  print "Sleeping 2 seconds...\n" if $DEBUG;
  sleep 2;

  # actually exit
  print "Exiting\n" if $DEBUG;
  exit 0;
}


sub reload_config {
  my $self = shift;

  # TODO: write this!
}


sub config {
  my ($self) = @_;

  return $self->{config};
}


# this steps through the config, creating objects when appropriate
sub process_config {
  my $self = shift;

  # make sure our users and channels are wiped, this is for when
  # we try to do config reloading.
  $self->{users} = undef;
  $self->{channels} = undef;

  # if there are users defined
  #   foreach user
  #     create a user object inside the bot object
  #     foreach admin listed in the config
  #       if this user is an admin
  #         set his/her admin flag

  if ($self->config->value('user')) {
    foreach my $user (keys(%{$self->config->value('user')})) {
      print "process_config: loading user '$user'\n" if $DEBUG;
      $self->{users}{$user} =
          new Perlbot::User($user,
                            $self->config->value(user => $user => 'flags'),
                            $self->config->value(user => $user => 'password'),
                            @{$self->config->value(user => $user => 'hostmask')});
      foreach my $admin ($self->config->value(bot => 'admin')) {
        if($admin eq $user) {
          print "process_config: $admin  is an admin\n" if $DEBUG;
          $self->{users}{$user}->admin(1);
        }
      }
    }
  }

  # if there are channels defined
  #   foreach channel
  #     create a channel object
  #     foreach op listed in the config
  #       add them as an op if they exist as a user
  #     put the channel into the bot object
  
  if ($self->config->value('channel')) {  
    foreach my $channel (keys(%{$self->config->value('channel')})) {
      print "process_config: loading channel '$channel'\n" if $DEBUG;
      my $chan =
          new Perlbot::Chan(name    => normalize_channel($channel),
                            flags   => $self->config->value(channel => $channel => 'flags'),
                            key     => $self->config->value(channel => $channel => 'key'),
                            logging => $self->config->value(channel => $channel => 'logging'),
                            logdir  => $self->config->value(bot => 'logdir'));
      
      foreach my $op ($self->config->value(channel => $channel => 'op')) {
        $op or next;
        $chan->add_op($op) if (exists($self->{users}{$op}));
      }

      $self->{channels}{$channel} = $chan;

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
  my $nick;
  my $ircname;

  my $handlers;

  # make an ircobject if one doesn't exist yet
  if (!$self->{ircobject}) {
    $self->{ircobject} = new Net::IRC;
    $self->{ircobject}{_debug} = 1 if $DEBUG >= 10;
  }

  # if we already have a connection, back up our handlers
  if ($self->{ircconn}) { # had a connection
    $handlers = $self->{ircconn}{_handler};
  }

  # if the server we've been given exists
  #   set all our variables
  #   set our ircconn object to the new one

  if ($self->config->value(server => $index)) {
    $server   = $self->config->value(server => $index => 'address'); # or die ("Server $i has no address specified\n");
    $port     = $self->config->value(server => $index => 'port');
    $password = $self->config->value(server => $index => 'password');
    $nick     = $self->config->value(bot => 'nick');
    $ircname  = $self->config->value(bot => 'ircname');

    $port ||= 6667;
    $password ||= '';
    $nick ||= 'perlbot';
    $ircname ||= 'imabot';

    print "connect: attempting to connect to server: $server\n" if $DEBUG;

    $self->{ircconn} =
        $self->{ircobject}->newconn(Nick => $nick,
                                    Server => $server,
                                    Port => $port,
                                    Password => $password,
                                    Ircname => $ircname);
  }

  # if our connection exists and it's actually connected
  #   if we had a backup of our handlers, jam it into this ircconn
  #   set out curnick appropriately
  #   ignore any hostmasks specified in the config
  #   return the connection
  # else fail

  if ($self->{ircconn} && $self->{ircconn}->connected()) {
    print "connect: connected to server: $server\n" if $DEBUG;

    if($handlers) { $self->{ircconn}{_handler} = $handlers; }

    $self->{curnick} = $nick;

    foreach my $hostmask ($self->config->value(bot => 'ignore')) {
      $self->{ircconn}->ignore('all', $hostmask);
    }

    return $self->{ircconn};
  } else {
    return undef;
  }
}


sub plugins {
  my ($self) = @_;

  return @{$self->{plugins}};
}

# loads all our plugins
sub load_all_plugins {
  my $self = shift;

  my @plugins;
  my @plugins_found = $self->find_plugins;
  my @noload = $self->config->value(bot => 'noload');

  # foreach plugin
  #   if it's listed in @noload
  #     print debug message, but do nothing else
  #   else
  #     push it onto our list of plugins to load

  foreach my $plugin (@plugins_found) {
    if (grep {lc($plugin) eq lc($_)} @noload) {
      print "load_all_plugins: Skipping '$plugin': noload\n" if $DEBUG;
    } else {
      push @plugins, $plugin;
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
  
  foreach my $plugindir ($self->config->value(bot => 'plugindir')) {
    opendir(PDH, $plugindir);
    foreach my $plugin (readdir(PDH)) {
      # ignore '.' and '..' silently
      if ($plugin eq '.' or $plugin eq '..') {
        next;
      }
      # ignore non-existent plugin subdirs
      my $dir = File::Spec->catdir($plugindir, $plugin);
      if (! -d $dir) {
        print "find_plugins: Ignoring '$plugin': $dir is not a directory\n" if $DEBUG;
        next;
      }
      # ignore subdirs without a Plugin.pm
      my $module = File::Spec->catfile($dir, "${plugin}.pm");
      if (! -f $module) {
        print "find_plugins: Ignoring '$plugin': no ${plugin}.pm in $dir\n" if $DEBUG;
        next;
      }

      # success!
      print "find_plugins: Found '$plugin'\n" if $DEBUG;
      push @found_plugins, $plugin;
      push @INC, $dir;
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
#   1 if load succeeded
sub load_plugin {
  my ($self, $plugin) = @_;

  print "load_plugin: loading plugin: $plugin\n" if $DEBUG;
  eval "require ${plugin}";  # try to import the plugin's package
  # check for module load error
  if ($@) {
    print $@ if $DEBUG;
    return 0;
  }
  # determine path to plugin subdirectory
  my $pluginfile = $INC{"${plugin}.pm"};
  my (undef,$pluginpath,undef) = File::Spec->splitpath($pluginfile);
  $pluginpath = File::Spec->canonpath($pluginpath);
  my $pluginref = eval "new Perlbot::Plugin::${plugin}(\$self, \$pluginpath)";
  # check for constructor error
  if ($@) {
    print $@ if $DEBUG;
    return 0;
  }

  # call init on our plugin
  # push it into the bot's internal list
  # return the pluginref for fun

  $pluginref->init;
  push @{$self->{plugins}}, $pluginref;
  return $pluginref;
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

  unless ($self->{handlers}{$event}) {
    $self->{handlers}{$event} = {};
    $self->{ircconn}->add_handler($event, sub { $self->event_multiplexer(@_) });
  }

  # add this handler to the bot's internal handlers

  $self->{handlers}{$event}{$plugin} = $coderef;
}

# Removes the handler for one event type for a given plugin
# params:
#   1) plugin name
#   2) event type (same as param 1 to add_handler)
sub remove_handler {
  my $self = shift;
  my ($event, $plugin) = @_;

  # if the bot knows about at least one handler for this event type
  #   if the given plugin has actually registered a callback for this type
  #     delete that callback

  if($self->{handlers}{$event}) {
    if($self->{handlers}{$event}{$plugin}) {
      delete $self->{handlers}{$event}{$plugin};
    }
  }
  # Net::IRC doesn't provide handler removal functionality, so there's
  # nothing more to do here.
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

  print "event_multiplexer: Got event '".$event->type."'\n" if $DEBUG >= 3;
  foreach my $plugin (keys(%{$self->{handlers}{$event->type}})) {
    if (exists($self->{handlers}{$event->type}{$plugin})) {
      print "  -> dispatching to '$plugin'\n" if $DEBUG >= 3;
      my $handler = $self->{handlers}{$event->type}{$plugin};
      &$handler($event, $user, $text);
    } else {
      # If we get here, we must have already processed an unload
      # request for this plugin in the core handler, so we need
      # to be careful to skip it here!
      print "  -> '$plugin' unloaded -- skipping\n" if $DEBUG >= 3;
    }
  }

}

# removes all handlers and sends all waiting events, used prior to shutdown
sub empty_queue {
  my ($self) = @_;

  delete $self->{handlers};  # make sure no handlers are triggered while we do this
  while ($self->{ircobject}->queue) {
    $self->{ircobject}->do_one_loop;
  }
}

# takes a hostmask and returns a user if one exists that matches
sub get_user {
  my $self = shift;
  my $hostmask = shift;
  my @tempusers;

  # foreach user
  #   foreach of their configured hostmasks
  #     if the given hostmask matches their configured one
  #       push them onto the list of matching users
  #       go back to the foreach user loop

  foreach my $user (values(%{$self->{users}})) {
    foreach my $tempmask (@{$user->{hostmasks}}) {
      if($hostmask =~ /^$tempmask$/i) {
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

  if(@tempusers == 1) {
    return $tempusers[0];
  } elsif(@tempusers > 1) {
    if($DEBUG) {
      print "Multiple users matched $hostmask !\n"; print Dumper(@tempusers);
    }
  }
  return undef;

}

# sends out the msg on the front of the queue and (re-)schedules itself
sub process_queue {
  my ($self) = @_;

  # if there's something on the queue, send it and schedule this method to
  # be called again in a bit.  otherwise, just set the empty_queue flag.
  my $params = shift(@{$self->{msg_queue}});
  if ($params) {
    print "process_queue: sending head of queue: $params->[0] / $params->[1]\n" if $DEBUG >= 3;
    $self->{ircconn}->privmsg(@$params);
    print "==>", $self->{ircconn}->schedule(1, \&process_queue, $self), "\n";
  } else {
    print "process_queue: queue now empty\n" if $DEBUG >= 3;
    $self->{empty_queue} = 1;
  }
}

# send a msg to a nick or channel
sub msg {
  my $self = shift;
  my $target = shift;
  my $text = shift;

  # push msg on the queue, and process the queue if it was previously empty
  # (then flag the queue as non-empty)
#  push(@{$self->{msg_queue}}, [$target, $text]);
#  print "msg: queueing $target / $text\n" if $DEBUG >= 3;
#  if ($self->{empty_queue}) {
#    print "  queue was empty, processing\n" if $DEBUG >= 3;
#    $self->process_queue;
#    $self->{empty_queue} = 0;
#  }

  $self->{ircconn}->privmsg($target, $text);

}

# joins a channel
sub join {
  my $self = shift;
  my $channel = shift;

  # if logging for this channel is on
  #   open the logfile

  if($channel->{logging} eq 'yes') {
    $channel->{log}->open();
  }

  # if there's a configured channel key
  #   join using the key
  # else
  #   just join the channel
  # call a names event so we can later populate the channel's member list

  if($channel->{key}) {
    $self->{ircconn}->join($channel->{name}, $channel->{key});
  } else {
    $self->{ircconn}->join($channel->{name});
  }
  $self->{ircconn}->names($channel->{name});
}

sub part {
  my $self = shift;
  my $channel = shift;

  $self->{ircconn}->part($channel->{name});
  if($channel->{log}) {
    $channel->{log}->close();
  }
}

sub op {
  my $self = shift;
  my $channel = shift;
  my $target = shift;

  $self->{ircconn}->mode($channel, '+o', $target);
}

sub deop {
  my $self = shift;
  my $channel = shift;
  my $target = shift;

  $self->{ircconn}->mode($channel, '-o', $target);
}

sub nick {
  my $self = shift;
  my $nick = shift;

  $self->{curnick} = $nick;
  $self->{ircconn}->nick($nick);
  return $self->{curnick};
}

sub whois {
  my $self = shift;
  my $target = shift;

  $self->{ircconn}->whois($target);
}

sub dcc_send {
  my $self = shift;
  my $nick = shift;
  my $filename = shift;

  $self->{ircconn}->new_send($nick, $filename);
} 

sub dcc_chat {
  my $self = shift;
  my $nick = shift;
  my $host = shift;

  $self->{ircconn}->new_chat(1, $nick, $host);
}

1;
