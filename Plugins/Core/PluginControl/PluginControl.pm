package Perlbot::Plugin::PluginControl;

use strict;
use base qw(Perlbot::Plugin);
use Perlbot;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

#  $self->want_public(0);
#  $self->want_fork(0);

  $self->hook( trigger => 'loadplugin', coderef => \&load_plugin, authtype => 'admin' );
  $self->hook( trigger => 'unloadplugin', coderef => \&unload_plugin, authtype => 'admin' );
  $self->hook( trigger => 'reloadplugin', coderef => \&reload_plugin, authtype => 'admin' );
  $self->hook( trigger => 'reloadallplugins', coderef => \&reload_all_plugins, authtype => 'admin' );
}


sub load_plugin {
  my ($self, $user, $text) = @_;

  my $plugin_name = $self->validate_input($text) or return;
  $self->perlbot->find_plugins();
  if ($self->perlbot->load_plugin($plugin_name)) {
    $self->reply("Successfully loaded plugin '$plugin_name'");
  } else {
    $self->reply("Couldn't load plugin '$plugin_name'");
  }
}


sub unload_plugin {
  my ($self, $user, $text) = @_;

  my $plugin_name = $self->validate_input($text) or return;

  if ($self->perlbot->unload_plugin($plugin_name)) {
    $self->reply("Successfully unloaded plugin '$plugin_name'");
  } else {
    $self->reply("Couldn't unload plugin '$plugin_name'");
  }
}


# I can even reload myself, honest!  Can't unload then load, have to
# reload.  If you just unload me first, you get caught with your pants
# down, since there's no way to load me back up.  :)
sub reload_plugin {
  my ($self, $user, $text) = @_;

  my $plugin_name = $self->validate_input($text) or return;

  my $ret = $self->perlbot->reload_plugin($text);
  # reload_plugin returns errors as scalar refs
  if (ref($ret) eq 'SCALAR') {
    $self->display_reload_error($$ret, $plugin_name);
  } elsif ($ret == 1) {
    $self->reply("Successfully reloaded plugin '$plugin_name'");
  } else {
    $self->reply("Unknown plugin reload error for plugin '$plugin_name");
  }
}


sub reload_all_plugins {
  my ($self, $user, $text) = @_;

  foreach my $plugin (grep { $_ !~ /PluginControl/ } @{$self->perlbot->plugins}) {
    my $ret = $self->perlbot->reload_plugin($plugin->name);
    if (ref($ret) eq 'SCALAR') {
      $self->display_reload_error($$ret, $plugin->name);
    }
  }

  $self->reply("Finished reloading all plugins");
}


sub display_reload_error {
  my ($self, $error, $plugin_name) = @_;

  if ($error eq 'unload') {
    $self->reply("Couldn't unload plugin '$plugin_name'");
  } elsif ($error eq 'load') {
    $self->reply("Failed to reload plugin '$plugin_name'; it remains unloaded");
  }
}

# Validates and parses the input string.
#
# returns:
#   If string is valid, returns the plugin name.
#   If invalid, replies with an error and returns undef.
# params:
#   1) input string to validate
sub validate_input {
  my ($self, $text) = @_;

  if (length($text) == 0) {
    $self->reply('You must specify a plugin name');
    return undef;
  }
  if ($text !~ /^\w+$/) {
    $self->reply('Please specify only one plugin name');
    return undef;
  }
  if ($text =~ /PluginControl/) {
    $self->reply('Sorry, PluginControl cannot be modified.');
    return undef;
  }

  return $text;
}


1;
