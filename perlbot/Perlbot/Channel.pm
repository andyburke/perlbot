package Perlbot::Channel;

use Perlbot::Logs;
use strict;


sub new {
  my $class = shift;
  my ($name, $config) = @_;
  my $singlelogfile = 0;

  if (lc($config->value(channel => $name => 'singlelogfile')) eq 'yes') {
    $singlelogfile = 1;
  }

  my $self = {
    config   => $config,
    name     => $name,
    log      => new Perlbot::Logs($config->value(bot => 'logdir'), $name, $singlelogfile),
    members  => {},
  };

  bless $self, $class;
  return $self;
}

sub log_write {
    my $self = shift;
    if ($self->logging && $self->logging eq 'yes') {
	$self->{log}->write(@_);
    }
}

sub config {
  my $self = shift;
  return $self->{config};
}

# name is read-only!
sub name {
    my $self = shift;
    return $self->{name};
}

sub flags {
    my $self = shift;
    $self->config->value(channel => $self->name => 'flags') = shift if @_;
    return $self->config->value(channel => $self->name => 'flags');
}

sub key {
    my $self = shift;
    $self->config->value(channel => $self->name => 'key') = shift if @_;
    return $self->config->value(channel => $self->name => 'key');
}

sub logging {
    my $self = shift;
    $self->config->value(channel => $self->name => 'logging') = shift if @_;
    return $self->config->value(channel => $self->name => 'logging');
}

sub limit {
    my $self = shift;
    $self->config->value(channel => $self->name => 'limit') = shift if @_;
    return $self->config->value(channel => $self->name => 'limit');
}

sub ops {
    my $self = shift;
    return $self->config->value(channel => $self->name => 'op');
}

sub is_op {
  my $self = shift;
  my $user = shift;

  if($user && (grep {$_ eq $user->name } @{$self->ops})) {
    return 1;
  }

  return 0;
}

sub add_member {
  my $self = shift;
  my $nick = shift;
  my $oldnick = shift;

  $self->{members}{$nick} = 1;
}

sub remove_member {
  my $self = shift;
  my $nick = shift;

  if (exists($self->{members}{$nick})) {
    delete $self->{members}{$nick};
  }
}

sub is_member {
  my $self = shift;
  my $nick = shift;

  if ($self->{members}{$nick}) {
    return 1;
  } else {
    return 0;
  }
}

sub add_op {
    my $self = shift;
    my $user = shift;

    defined $user or return;
    if (! grep {$_ eq $user} @{$self->ops}) {
      push @{$self->config->value(channel => $self->name => 'op')}, $user;
    }
}

1;
