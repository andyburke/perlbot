package Perlbot::Plugin::ConnectionManagement;

use Perlbot::Utils;
use Perlbot;
use Plugin;

@ISA = qw(Plugin);

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->{perlbot}->add_handler('endofmotd', sub { $self->join_channels }, $self->{name});
  $self->{perlbot}->add_handler('nomotd', sub { $self->join_channels }, $self->{name});

  $self->{perlbot}->add_handler('disconnect', sub { $self->reconnect(@_) }, $self->{name});

  $self->{perlbot}->add_handler('nicknameinuse', sub { $self->cycle_nick(@_) }, $self->{name});
  $self->{perlbot}->add_handler('nickcollision', sub { $self->cycle_nick(@_) }, $self->{name});


}

# ============================================================
# event handlers
# ============================================================

sub join_channels {
  my $self = shift;

  print "joining channels\n" if $DEBUG;

  foreach my $channel (values(%{$self->{perlbot}->{channels}})) {
    print "Joining $channel->{name}\n" if $DEBUG;
    $self->{perlbot}->join($channel);
  }

}

sub reconnect {
  my $self = shift;
  my $event = shift;
  my $old_server = $event->{from};
  my $server;
  my $i;

  if ($$ == 0) {    # exit if we're a child...
    exit;
  }

  if ($DEBUG) {
    print "Disconnected from: $old_server\n";
    $event->dump();
    print "---End dump...\n";
  }

  while(!$self->{perlbot}{ircconn}->connected()) {
    for($i = 0; $i<$self->{perlbot}->config('server'); $i++) {
      if($self->{perlbot}->config(server => $i => 'address') eq $old_server) { $i++; last; }
      if($i == $self->{perlbot}->config('server') - 1) { $i = 0; $old_server = ''; last; }
    }

    for( ; $i < $self->{perlbot}->config('server'); $i++) {
      $server = join(':', $self->{perlbot}->config(server => $i => 'address'), $self->{perlbot}->config(server => $i => 'port'));
      print "trying $server\n" if $debug;
      $self->{perlbot}{ircconn}->server($server);
      $self->{perlbot}{ircconn}->connect();
      if($self->{perlbot}{ircconn}->connected()) {
        return;
      }
      if($i == $self->{perlbot}->config('server') - 1) { last; }
    }

    print "Sleeping for 10 seconds...\n" if $debug;
    sleep(10);
    $i = 0;
    $old_server = '';
  }
}

sub cycle_nick {
  my $self = shift;
  my $event = shift;

  $self->{perlbot}->nick($self->{perlbot}->{curnick} . $self->{perlbot}->config(bot => 'nickappend'));
}

1;
