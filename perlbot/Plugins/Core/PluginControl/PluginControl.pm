package Perlbot::Plugin::PluginControl;

use Perlbot;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;

  $self->author('Andrew Burke');
  $self->contact('burke@bitflood.org');
  $self->version('1.0.0');
  $self->url('http://perlbot.sourceforge.net');

  $self->want_public(0);
  $self->want_fork(0);

  $self->hook_admin('plugins', \&plugins);
}

sub plugins {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  if (!$text) { # no command specified
    return;
  }

  my ($command, $param) = split(' ', $text, 2);

  if ($command eq 'load' or $command eq 'start') {
    if (!$param) {
      $self->reply('You need to specify a plugin to load!');
      return;
    }
    if ($self->perlbot->load_plugin($param)) {
      $self->reply("Successfully loaded plugin '$param'");
    } else {
      $self->reply("Couldn't load plugin '$param'");
    }
  } elsif ($command eq 'unload' or $command eq 'stop') {
    $self->reply('command not yet implemented');
  } else {
    $self->reply("Unknown plugin command: '$command'");
  }

}

1;
