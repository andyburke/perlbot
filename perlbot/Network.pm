package Network;

use Net::IRC;
use strict;

sub new {
    my $class = shift;
    my $name = shift;
    my $nick = shift;
    my $ircname = shift;

    my $self = {
	irc         => 0,
	name        => $name,
	nick        => $nick,
	ircname     => $ircname,
	connection  => 0,
	servers     => []
	};

    bless $self, $class;
    return $self;
}

sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    return $self->{name};
}

sub nick {
    my $self = shift;
    $self->{nick} = shift if @_;
    return $self->{nick};
}

sub ircname {
    my $self = shift;
    $self->{ircname} = shift if @_;
    return $self->{ircname};
}

sub add_irc_object {
    my $self = shift;
    my $irc = shift;

    $self->{irc} = $irc;
}

sub add_server {
    my $self = shift;
    my $server = shift;
    my $port = shift;
    my $server = join(':', $server, $port) if $port;

    push @{$self->{servers}}, $server;
}

sub connect {
    my $self = shift;
    my $server = $self->{servers}[0];
    my $port = (split(/:/, $server))[1];
    $server = (split(/:/, $server))[0];

    if(!$self->{irc}) {
	return 0;
    } else {
	print "Connecting to: $server:$port...\n";
	$self->{connection} = $self->{irc}->newconn(Nick => $self->{nick},
						    Server => $server,
						    Port => $port,
						    Ircname => $self->{ircname});
	if($self->{connection}->connected()) {
	    print "Connected... (" . $self->{connection}->connected() . ")\n";
	} else {
	    print "Not connected... ?\n";
	}
    }
}

1;
