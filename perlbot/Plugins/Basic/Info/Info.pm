package Perlbot::Plugin::Info;

use Perlbot;
use Perlbot::User;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_fork(0);

  $self->hook('status', \&status);
  $self->hook('listplugins', \&listplugins);
  $self->hook('listchannels', \&listchannels);
  $self->hook('listusers', \&listusers);
}

sub status {
  my $self = shift;
  my $user = shift;

  $self->reply("Perlbot $Perlbot::VERSION / $Perlbot::AUTHORS");
  $self->reply("Uptime: " . $self->perlbot->humanreadableuptime());
  $self->reply("Known users: " . keys(%{$self->perlbot->users}));
  $self->reply("Channels active: " . keys(%{$self->perlbot->channels}));
  $self->reply("Plugins active: " . @{$self->perlbot->plugins});

}

sub listplugins {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my @plugins;

  if (!$text) {
    foreach my $plugin (@{$self->perlbot->plugins}) {
      push(@plugins, $plugin->name);
    }
    $self->reply('plugins: ' . join(' ', sort(@plugins)));
    return;
  }
}

sub listchannels {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @channels;

  foreach my $channel (keys(%{$self->perlbot->channels})) {
    push(@channels, $channel);
  }

  $self->reply('Current channels: ' . join(' ', sort(@channels)));
}

sub listusers {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @users;

  foreach my $user (keys(%{$self->perlbot->users})) {
    push(@users, $user);
  }

  $self->reply('Current users: ' . join(' ', sort(@users)));
}

1;
