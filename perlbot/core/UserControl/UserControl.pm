package Perlbot::Plugin::UserControl;

use Perlbot;
use Perlbot::Utils;
use Perlbot::Chan;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

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
    $self->{perlbot}->nick($newnick);
  } else {
    $self->reply('You must specify a new nickname!');
  }
}

sub quit {
  my $self = shift;
  my $user = shift;
  my $quitmsg = shift;

  $self->{perlbot}->shutdown($quitmsg);
}

sub join {
  my $self = shift;
  my $user = shift;
  my ($channel, $key) = split(' ', shift, 2);

  $channel = normalize_channel($channel);

  my $config = $self->{perlbot}->read_config();
  my $chan_hash = $config->{channel}{$channel};
  if($chan_hash) {
    my $chan = new Perlbot::Chan(name => $channel,
                                 flags => $chan_hash->{flags},
                                 key => $chan_hash->{key},
                                 logging => $chan_hash->{logging},
                                 logdir => $self->{perlbot}{config}{bot}{logdir});
    foreach my $op (@{$chan_hash->{op}}) {
      $chan->add_op($op) if (exists($self->{perlbot}{users}{$op}));
    }

    $self->{perlbot}{channels}{$chan->{name}} = $chan;
    $self->{perlbot}->join($chan);
    
    return;
  }
  my $chan = new Perlbot::Chan(name => normalize_channel($channel),
                               key => $key);
                        
  $self->{perlbot}{channels}{$chan->{name}} = $chan;
  $self->{perlbot}->join($chan);
}

sub part {
  my $self = shift;
  my $user = shift;
  my $channel = shift;

  $channel = normalize_channel($channel);

  if($self->{perlbot}->{channels}->{$channel}) {
    $self->{perlbot}->part($self->{perlbot}->{channels}->{$channel});
    delete $self->{perlbot}->{channels}->{$channel};
  } else {
    $self->reply("I am not currently in $channel");
  }
}

sub cycle {
  my $self = shift;
  my $user = shift;
  my $channel = shift;

  $channel = normalize_channel($channel);

  if($self->{perlbot}->{channels}->{$channel}) {
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

  $self->{perlbot}->msg($channel, $text);
}

sub msg {
  my $self = shift;
  my $user = shift;
  my ($target, $text) = split(' ', shift, 2);

  $self->{perlbot}->msg($target, $text);
}

sub op {
  my $self = shift;
  my $user = shift;
  my $channel = shift;

  if(!$channel) {
    # FIXME: tell them about help here
    return;
  }

  $channel = normalize_channel($channel);

  if(!$user) {
    $self->reply('You are not a known user, authenticate yourself first!');
    return;
  }

  if(!$self->{perlbot}->{channels}->{$channel}) {
    $self->reply("No such channel: $channel");
    return;
  }

  if(!exists($self->{perlbot}->{channels}->{$channel}->{ops}->{$user->name()})) {
    $self->reply("You are not a valid op for channel $channel");
    return;
  } else {
    $self->{perlbot}->op($channel, $user->{curnick});
  }
}

1;
