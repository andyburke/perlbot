package Perlbot;

use PerlbotUtils;
use Net::IRC;
use Data::Dumper;

use User;
use Chan;


$VERSION = '1.5.1';
$AUTHORS = 'burke@bitflood.org / jmuhlich@bitflood.org';

sub new {
  my $class = shift;
  my $configfile = shift; $configfile ||= './config';

  my $self = {
    starttime => time(),
    config => {},
    configfile => $configfile, 
    ircobject => undef,
    ircconn => undef,
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

sub start {
  my $self = shift;

  $self->read_config or die "Couldn't read $self->{configfile}!!\n";
  $self->process_config;

  $self->connect or die "Couldn't connect to any servers!!\n";

  $self->load_all_plugins;

  $self->{ircobject}->start();
}

sub shutdown {
  my ($self, $quitmsg) = @_;

  print "Shutting down...\n" if $DEBUG;

  $quitmsg ||= 'goodbye';
  $self->{ircconn}->quit($quitmsg);

  my @plugins_copy = $self->plugins;
  foreach my $plugin (@plugins_copy) {
    $plugin->shutdown;
  }

  write_config($self->{configfile}, $self->{config});

  print "Sleeping 2 seconds...\n" if $DEBUG;
  sleep 2;
  print "Exiting\n" if $DEBUG;
  exit 0;
}


sub read_config {
  my $self = shift;

  $self->{config} = PerlbotUtils::read_generic_config($self->{configfile});
}

sub write_config {
  my $self = shift;

  PerlbotUtils::write_generic_config($self->{configfile}, $self->{config});
}

sub reload_config {
  my $self = shift;

  # TODO: write this!
}


sub config {
  my ($self, $class, $key, $field) = @_;
  my $ref;

  $ref = $self->{config};
  if (!defined $class) {
    # return entire config
    return $ref;
  }

  $ref = $ref->{$class};
  if (!defined $key) {
    # return array or hashref of all objects in a given class
    if (ref($ref) eq 'ARRAY') {
      return @{$ref};
    } else {
      return $ref;
    }
  }

  if (ref($ref) eq 'ARRAY') {
    if (@{$ref} == 1 and $key =~ /\D/) {
      $field = $key;
      $key = 0;
    }
    $ref = $ref->[$key];
  } else {
    $ref = $ref->{$key};
  }
  if (!defined $field) {
    # return a given object in a given class
    return $ref;
  }

  # return array of all fields in a given object in a given class,
  # or a single value if there is only one
  $ref = $ref->{$field};
  if (ref($ref) eq 'ARRAY') {
    if (@{$ref} == 1) {
      return $ref->[0];
    } else {
      return @{$ref};
    }
  } else {
    return $ref;
  }
}


sub process_config {
  my $self = shift;

  $self->{users} = undef;
  $self->{channels} = undef;

  foreach my $user (keys(%{$self->config('user')})) {
    print "process_config: loading user '$user'\n" if $DEBUG;
    $self->{users}{$user} =
      new User($user,
               $self->config(user => $user => 'flags'),
               $self->config(user => $user => 'password'),
               $self->config(user => $user => 'hostmask'));
    foreach my $admin ($self->config(bot => 'admin')) {
      if($admin eq $user) {
        print "process_config:   is an admin\n" if $DEBUG;
        $self->{users}{$user}->admin(1);
      }
    }
  }

  foreach my $channel (keys(%{$self->config('channel')})) {
    print "process_config: loading channel '$channel'\n" if $DEBUG;
    my $chan =
      new Chan(name => normalize_channel($channel),
               flags => $self->config(channel => $channel => 'flags'),
               key => $self->config(channel => $channel => 'key'),
               logging => $self->config(channel => $channel => 'logging'),
               logdir => $self->config(bot => 'logdir'));

    foreach my $op (@{$self->config(channel => $channel => 'op')}) {
      $chan->add_op($op) if (exists($self->{users}{$op}));
    }

    $self->{channels}{$channel} = $chan;

  }

  push @INC, $self->config(bot => 'plugindir');
}

sub connect {
  my $self = shift;

  my $server;
  my $port;
  my $nick;
  my $ircname;

  $self->{ircobject} = new Net::IRC;

  my $i = 0;
  while(!$self->{ircconn}) {

    $server = $self->config(server => $i => 'address'); # or die ("Server $i has no address specified\n");
    $port = $self->config(server => $i => 'port'); $port ||= 6667;
    $nick = $self->config(bot => 'nick'); $nick ||= 'perlbot';
    $ircname = $self->config(bot => 'ircname'); $ircname ||= 'imabot';

    print "connect: attempting to connect to server: $server\n" if $Perlbot::DEBUG;

    $self->{ircconn} =
      $self->{ircobject}->newconn(Nick => $nick,
                                  Server => $server,
                                  Port => $port,
                                  Ircname => $ircname);
    $i++;
  }

  print "connect: onnected to server: $server\n" if $Perlbot::DEBUG;

  $self->{curnick} = $nick;

  return $self->{ircconn};
}

sub plugins {
  my ($self) = @_;

  return @{$self->{plugins}};
}

sub load_all_plugins {
  my $self = shift;

  my @plugins;
  my @plugins_found = $self->find_plugins;
  my @noload = $self->config(bot => 'noload');

  # drop noload'ed plugins
  foreach my $plugin (@plugins_found) {
    if (grep {lc($plugin) eq lc($_)} @noload) {
      print "load_all_plugins: Skipping '$plugin': noload\n" if $DEBUG;
    } else {
      push @plugins, $plugin;
    }
  }

  foreach my $plugin (@plugins) {
    $self->load_plugin($plugin);
  }
}

# Looks for all plugins on disk in all plugindirs, doing some basic
# sanity checks (making sure the plugin perl module file exists).
sub find_plugins {
  my ($self) = @_;
  my @found_plugins;

  foreach my $plugindir ($self->config(bot => 'plugindir')) {
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
      my $module = File::Spec->catfile($dir, 'Plugin.pm');
      if (! -f $module) {
        print "find_plugins: Ignoring '$plugin': no Plugin.pm in $dir\n" if $DEBUG;
        next;
      }

      # success!
      print "find_plugins: Found '$plugin'\n" if $DEBUG;
      push @found_plugins, $plugin;
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
  eval "require ${plugin}::Plugin";  # try to import the plugin's package
  # check for module load error
  if ($@) {
    print $@ if $DEBUG;
    return 0;
  }
  # determine path to plugin subdirectory
  my $pluginfile = $INC{File::Spec->catfile($plugin,'Plugin.pm')};
  my (undef,$pluginpath,undef) = File::Spec->splitpath($pluginfile);
  $pluginpath = File::Spec->canonpath($pluginpath);
  my $pluginref = eval "new ${plugin}::Plugin(\$self, \$pluginpath)";
  # check for constructor error
  if ($@) {
    print $@ if $DEBUG;
    return 0;
  }

  # success!
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

  # do some init stuff if nobody has hooked this event yet
  unless ($self->{handlers}->{$event}) {
    $self->{handlers}->{$event} = {};                    # create the hash ref
    # add our 'multiplexer' sub as the handler
    $self->{ircconn}->add_handler($event, sub { $self->event_multiplexer(@_); });
  }
  $self->{handlers}->{$event}->{$plugin} = $coderef;       # store the code ref
}

# Removes all handlers for a given plugin
# params:
#   1) plugin name
sub remove_handlers {
  my $self = shift;
  my $plugin = shift;;

  # loop over all the hash refs that store the code refs
  foreach my $ref (values(%{$self->{handlers}})) {
    delete $ref->{$plugin};
  }
}

sub event_multiplexer {
  my $self = shift;
  my $conn = shift;
  my $event = shift;
  my $text = $event->{args}[0];
  my $user = $self->get_user($event->{from});

  $| = 1;
  foreach my $plugin (keys(%{$self->{handlers}->{$event->type}})) {
    if (exists($self->{handlers}->{$event->type}->{$plugin})) {
      my $handler = $self->{handlers}->{$event->type}->{$plugin};
      &$handler($event, $user, $text);
    } else {
      # If we get here, we must have already processed an unload
      # request for this plugin in the core handler, so we need
      # to be careful to skip it here!
      if ($DEBUG > 2) { print "  (unloaded; skipping)\n" }
    }
  }

}

sub get_user {
  my $self = shift;
  my $hostmask = shift;
  my @tempusers;

  foreach my $user (values(%{$self->{users}})) {
    foreach my $tempmask (@{$user->{hostmasks}}) {
      if($hostmask =~ /^$tempmask$/i) {
        push(@tempusers, $user);
        last;
      }
    }
  }

  if(@tempusers == 1) {
    return $tempusers[0];
  } elsif(@tempusers > 1) {
    if($DEBUG) {
      print "Multiple users matched $hostmask !\n"; print Dumper(@tempusers);
    }
  }
  return undef;

}

sub msg {
  my $self = shift;
  my $target = shift;
  my $text = shift;

  $self->{ircconn}->privmsg($target, $text);
}

sub join {
  my $self = shift;
  my $channel = shift;

  if($channel->{logging} eq 'yes') {
    $channel->{log}->open();
  }

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
