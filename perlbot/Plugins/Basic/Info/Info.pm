package Perlbot::Plugin::Info;

use Perlbot;
use Perlbot::User;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_fork(0);

  $self->hook('status', \&status);
  $self->hook('plugins', \&listplugins); # backwards compat
  $self->hook('listplugins', \&listplugins);
  $self->hook('listchannels', \&listchannels);
  $self->hook('listchans', \&listchannels); # back compat
  $self->hook('listusers', \&listusers);
}

sub status {
  my $self = shift;
  my $user = shift;

  my $uptime = time() - $self->{perlbot}->{starttime};
  my $uptimedays = sprintf("%02d", $uptime / 86400);
  $uptime = $uptime % 86400;
  my $uptimehours = sprintf("%02d", $uptime / 3600);
  $uptime = $uptime % 3600;
  my $uptimeminutes = sprintf("%02d", $uptime / 60);
  $uptime = $uptime % 60;
  my $uptimeseconds = sprintf("%02d", $uptime);

  $self->reply("Perlbot $Perlbot::VERSION / $Perlbot::AUTHORS");
  $self->reply("Uptime: ${uptimedays}d:${uptimehours}h:${uptimeminutes}m:${uptimeseconds}s");
  $self->reply("Known users: " . keys(%{$self->{perlbot}->users}));
  $self->reply("Channels active: " . keys(%{$self->{perlbot}->channels}));
  $self->reply("Plugins active: " . @{$self->{perlbot}->plugins});

}

sub listplugins {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my @plugins;

  if (!$text) {
    foreach my $plugin (@{$self->{perlbot}->plugins}) {
      push(@plugins, $plugin->{name});
    }
    $self->reply('plugins: ' . join(' ', @plugins));
    return;
  }
}

sub listchannels {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @channels;

  foreach my $channel (keys(%{$self->{perlbot}->channels})) {
    push(@channels, $channel);
  }

  $self->reply('Current channels: ' . join(' ', sort(@channels)));
}

sub listusers {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my @users;

  foreach my $user (keys(%{$self->{perlbot}->users})) {
    push(@users, $user);
  }

  $self->reply('Current users: ' . join(' ', sort(@users)));
}

1;
