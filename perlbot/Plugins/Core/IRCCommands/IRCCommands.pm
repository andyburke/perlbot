package Perlbot::Plugin::IRCCommands;

use Perlbot;
use Perlbot::Utils;
use Perlbot::Channel;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_fork(0);

  $self->hook_admin('nick', \&nick);
  $self->hook_admin('quit', \&quit);
  $self->hook_admin('join', \&join);
  $self->hook_admin('part', \&part);
  $self->hook_admin('cycle', \&cycle);
  $self->hook_admin('say', \&say);
  $self->hook_admin('msg', \&msg);
  $self->hook('op', \&op);
}

sub nick {
  my $self = shift;
  my $user = shift;
  my $newnick = shift;

  if($newnick) {
    $self->perlbot->nick($newnick);
  } else {
    $self->reply('You must specify a new nickname!');
  }
}

sub quit {
  my $self = shift;
  my $user = shift;
  my $quitmsg = shift;

  $self->reply("Quitting...");
  $self->perlbot->shutdown($quitmsg);
}

sub join {
  my $self = shift;
  my $user = shift;
  my ($channel, $key) = split(' ', shift, 2);

  $channel = normalize_channel($channel);
  my $chan;
  if(defined($self->perlbot->config->value(channel => $channel))) {
    $chan = new Perlbot::Channel($channel, $self->perlbot->config, $self->perlbot());
  } else {
    $chan = new Perlbot::Channel($channel, new Perlbot::Config(), $self->perlbot());
  }
  $chan->key($key);
  $self->perlbot->channels->{$channel} = $chan;
  $self->perlbot->join($chan);
}

sub part {
  my $self = shift;
  my $user = shift;
  my $channel = shift;

  $channel = normalize_channel($channel);

  if ($self->perlbot->get_channel($channel)) {
    $self->perlbot->part($self->perlbot->get_channel($channel));
    delete $self->perlbot->channels->{$channel};
  } else {
    $self->reply("I am not currently in $channel");
  }
}

sub cycle {
  my $self = shift;
  my $user = shift;
  my $channel = shift;

  $channel = normalize_channel($channel);

  if ($self->perlbot->get_channel($channel)) {
    $self->part($user, $channel);
    $self->join($user, $channel);
  } else {
    $self->reply("I am not currently in $channel");
  }
}

sub say {
  my $self = shift;
  my $user = shift;
  my ($channel, $text) = split(' ', shift, 2);

  $channel = normalize_channel($channel);

  $self->perlbot->msg($channel, $text);
}

sub msg {
  my $self = shift;
  my $user = shift;
  my ($target, $text) = split(' ', shift, 2);

  $self->perlbot->msg($target, $text);
}

sub op {
  my $self = shift;
  my $user = shift;
  my $channel = shift;

  if (!$channel) {
    $self->reply_error("Please refer to the help for the IRCCommands plugin!");
    return;
  }

  $channel = normalize_channel($channel);

  if (!$user) {
    $self->reply('You are not a known user, authenticate yourself first!');
    return;
  }

  my $chan = $self->perlbot->get_channel($channel);
  if (!$chan) {
    $self->reply("No such channel: $channel");
    return;
  }

  if (! $chan->is_op($user)) {
    $self->reply("You are not a valid op for channel $channel");
  } else {
    $self->perlbot->op($channel, $user->{curnick});
  }
}


1;
