package Chan;

use Log;
use Perlbot;
use strict;


sub new {
    my ($class, $name, $flags, $key) = (shift, shift, shift, shift);

    my $self = {
      name     => $name,
      flags    => $flags ? join('', @{$flags}) : '',
      key      => $key,
      log      => new Log($name),
      logging  => 'no', #don't log by default...
      ops      => {},
      redirects => {}
      };
    
    bless $self, $class;
    return $self;
}

sub join {
    my $self = shift;
    my $priv_conn = shift;

    if($self->{logging} eq 'yes') {
	$self->{log}->open;
    }
    if($self->{key} ne '') {
      $priv_conn->join($self->{name}, $self->{key});
    } else {
      $priv_conn->join($self->{name});
    }
}

sub part {
    my $self = shift;
    my $priv_conn = shift;
    
    $priv_conn->part($self->{name});
    $self->{log}->close;
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

sub redirects {
    my $self = shift;
    return $self->{redirects};
}

sub add_op {
    my $self = shift;
    $self->{ops}->{$_[0]} = defined;
    # return the current number of ops (values() returns an array, but
    # since it's in a scalar context, add_op returns the size of the array)
    return scalar(values(%{$self->{ops}}));
}

sub add_redir {
    my $self = shift;
    foreach(@_) {
#	push @{$self->{redirects}}, to_channel($_);
	${$self->{redirects}}{$_} = $_;

    }
}

sub del_redir {
    my $self = shift;
    my $cur_redir = 0;

    foreach my $deletion (@_) {
	delete ${$self->{redirects}}{$deletion};
    }
}

sub send_redirs {
    my $self = shift;
    my $priv_conn = shift;
    my $nick = shift;
    my $chan_or_nick;

    foreach my $redir (values(%{$self->{redirects}})) {
	$priv_conn->privmsg(to_channel($redir), "[$self->{name}] <$nick> @_");
#	$priv_conn->privmsg($redir, "[$self->{name}] <$nick> @_");
    }
}


1;
