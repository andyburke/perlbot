package Perlbot::Channel;

use strict;

use Perlbot::Utils;
use Perlbot::Logs::Event;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(config name loggers logs members currentopped currentvoiced perlbot);

sub new {
  my $class = shift;
  my ($name, $config, $perlbot) = @_;

  my $self = fields::new($class);

  $self->config = $config;
  $self->name = $name;
  $self->members = {};
  $self->currentopped = {};
  $self->currentvoiced = {};
  $self->perlbot = $perlbot;
  $self->loggers = []; $self->initialize_loggers();
  $self->logs = $self->loggers->[0]; # first logger is default

  return $self;
}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  if(!exists($FIELDS{$field})) {
    die "AUTOLOAD: no such method/field '$field'";
  }

  debug("Got call for field: $field", 15);

  $self->{$field};
}

sub initialize_loggers {
  my $self = shift;

  $self->config->exists(channel => $self->name => 'log') or return;

  for(my $i = 0;
      $i < $self->config->array_get(channel => $self->name => 'log');
      $i++)
  {
    my $logtype;
    
    if($self->config->exists(channel => $self->name => log => $i => 'type')) {
      $logtype = $self->config->get(channel => $self->name => log => $i => 'type');
    } else {
      $logtype = $self->config->get(channel => $self->name => log => $i);
    }
    
    $logtype =~ /^\w+(::\w+)*$/ or die "Channel " . $self->name . ": Invalid logtype '$logtype'";
    debug("loading Logs package '$logtype'");
    
    # try to import the requested Logs package
    eval "
      local \$SIG{__DIE__}='DEFAULT';
      require Perlbot::Logs::${logtype};
    ";
    
    # check for package load error
    if ($@) {
      debug("  failed to load '$logtype': $@");
      return undef;
    }
    
    # try to construct the Logs object
    my $logger =
        eval "
          local \$SIG{__DIE__}='DEFAULT';
          new Perlbot::Logs::${logtype}(\$self->perlbot,
                                        \$self->name,
                                        \$self->config,
                                        \$i);
        ";
    
    if ($@ or !$logger) {
      debug("  failed construction of '$logtype': $@");
      return undef;
    }
    
    # add it to our logfacilties
    push(@{$self->loggers}, $logger);
  }
}

sub log_event {
  my $self = shift;
  
  # make the event once, here, so the time
  # is the same, regardless of how long
  # it takes us to get to any given
  # logger

  my $event = new Perlbot::Logs::Event(shift, $self->name);

  if ($self->is_logging) {
    foreach my $logger (@{$self->loggers}) {
      $logger->log_event($event);
    }
  }
}

sub flags {
    my $self = shift;
    $self->config->set(channel => $self->name => 'flags', shift) if @_;
    return $self->config->get(channel => $self->name => 'flags');
}

sub key {
    my $self = shift;
    # if the key is non-empty, or there is a previous key value to overwrite
    # (even with an empty value)
    if (@_ and ((defined $_[0] and length $_[0]) or
        $self->config->exists(channel => $self->name => 'key'))) {

        $self->config->set(channel => $self->name => 'key', shift) if @_;
    }
    return $self->config->get(channel => $self->name => 'key');
}

sub logging {
    my $self = shift;
    $self->config->set(channel => $self->name => 'logging', shift) if @_;
    return $self->config->get(channel => $self->name => 'logging');
}

sub limit {
    my $self = shift;
    $self->config->set(channel => $self->name => 'limit', shift) if @_;
    return $self->config->get(channel => $self->name => 'limit') or 0;
}

sub ops {
    my $self = shift;
    return $self->config->array_get(channel => $self->name => 'op');
}

sub is_op {
  my $self = shift;
  my $user = shift;

  if ($user and $self->ops and
      (grep {$_ eq $user->name } $self->ops)) {
    return 1;
  }

  return 0;
}

sub is_logging {
    my $self = shift;
    return ($self->logging and $self->logging eq 'yes');
}

sub add_member {
  my $self = shift;
  my $nick = shift;

  $self->members->{$nick} = 1;
}

sub remove_member {
  my $self = shift;
  my $nick = shift;

  if (exists($self->members->{$nick})) {
    delete $self->members->{$nick};
  }
}

sub clear_member_list {
  my $self = shift;
  
  $self->members = {};
}

sub is_member {
  my $self = shift;
  my $nick = shift;

  defined($self->members->{$nick}) ? return 1 : return 0;
}

sub add_op {
  my $self = shift;
  my $user = shift;
  
  defined $user or return;
  if (!$self->is_op($user)) {
    $self->config->array_push(channel => $self->name => 'op', $user->name);
  }
}

sub remove_op {
  my $self = shift;
  my $user = shift;
  
  my $old_count = $self->config->array_get(channel => $self->name => 'op');
  $self->config->array_delete(channel=> $self->name=> 'op', $user);
  my $removed_count = $old_count - $self->config->array_get(channel => $self->name => 'op');

  return $removed_count > 0;
}

sub is_current_op {
  my $self = shift;
  my $nick = shift;

  $self->currentopped->{$nick} ? return 1 : return 0;
}

sub add_current_op {
  my $self = shift;
  my $nick = shift;

  $self->currentopped->{$nick} = 1;
}

sub remove_current_op {
  my $self = shift;
  my $nick = shift;

  delete $self->currentopped->{$nick};
}

sub clear_currentopped_list {
  my $self = shift;

  $self->currentopped = {};
}

sub join {
    my $self = shift;
    # we used to do something here.  leaving the stub in for now.
}

sub part {
    my $self = shift;

    $self->logs->close;
}

sub DESTROY {
  # dummy
}

1;
