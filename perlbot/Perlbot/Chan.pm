package Perlbot::Chan;

use Perlbot::Logs;
use strict;


sub new {
  my $class = shift;
  my (%chanhash) = @_;

  my $self = {
    name     => $chanhash{'name'},
    flags    => $chanhash{'flags'},
    key      => $chanhash{'key'},
    log      => new Perlbot::Logs($chanhash{'logdir'}, $chanhash{'name'}),
    logging  => $chanhash{'logging'}, 
    limit    => $chanhash{'limit'},
    ops      => {},
    members  => {},
  };
    
  bless $self, $class;
  return $self;
}

sub log_write {
    my $self = shift;
    if($self->{logging} eq 'yes') {
	$self->{log}->write(@_);
    }
}

sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    return $self->{name};
}

sub flags {
    my $self = shift;
    $self->{flags} = shift if @_;
    return $self->{flags};
}

sub logging {
    my $self = shift;
    $self->{logging} = shift if @_;
    return $self->{logging};
}

sub ops {
    my $self = shift;
    return $self->{ops};
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

  if(exists($self->{memebers}{$nick})) {
    delete $self->{members}{$nick};
  }
}

sub is_member {
  my $self = shift;
  my $nick = shift;

  if($self->{members}{$nick}) {
    return 1;
  } else {
    return 0;
  }
}

sub add_op {
    my $self = shift;
    my $user = shift;

    $self->{ops}{$user} = 1;
    # return the current number of ops (values() returns an array, but
    # since it's in a scalar context, add_op returns the size of the array)
    return scalar(values(%{$self->{ops}}));
}

1;
