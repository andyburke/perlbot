# Jeremy Muhlich <jmuhlich@bitflood.org>
#
# Based on LogServer.pm by (mainly) Andrew Burke.
#
# TODO: make it use channel keys for password protection of the stats... ?
#       make this thing die cleanly
#       fork-at-birth not going to work here, bad idea anyway. set timeout?
#       split up plugin forking logic so we can re-use parts here

package Perlbot::Plugin::StatsServer;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot::Utils;

use HTTP::Daemon;
use HTTP::Response;
use HTTP::Headers;
use HTTP::Status;
use XML::Simple;
use Data::Dumper;

our $VERSION = '1.0.0';


sub init {
  my $self = shift;

  my $server = HTTP::Daemon->new(LocalAddr => $self->config->value(server => 'hostname'),
                                 LocalPort => $self->config->value(server => 'port'));
  if (!$server) {
    debug("Could not create StatsServer http server: $!");
    $self->_shutdown;
    return;
  }
  $self->{_server} = $server;

  my $select = IO::Select->new($server);
  $self->{_select} = $select;

  $self->want_msg(0);
  $self->want_fork(0);

  # remember we get a 'topic' even on channel joins too, so nothing
  # extra is needed to capture the initial topic.
  $self->hook_event('topic', \&set_topic);
  $self->hook(\&set_lastline);

  $self->{_topic_cache} = {};

  $self->timer;  # fire off the cycle
}

sub timer {
  my $self = shift;

  while ($self->{_select}->can_read(.0001)) {
    my $connection = $self->{_server}->accept;
    $self->handle_request($connection);
  }

  $self->perlbot->ircconn->schedule(1, sub { $self->timer });
}

sub handle_request {
  my $self = shift;
  my ($connection) = @_;

  my $pid;

  if (!defined($pid = fork)) {
    return;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = IGNORE;

  } else {
    # child

    $self->perlbot->ircconn->{_connected} = 0;

    while (my $request = $connection->get_request) {
      if ($request->method eq 'GET') {
        my $data = {};

        foreach my $channel (values %{$self->perlbot->channels}) {
          $chan_data = {name => $channel->name, topic => $self->{_topic_cache}{$channel->name}};
          push @{$data->{channel}}, $chan_data;
        }

        my $response_xml = qq{<?xml version="1.0"?>\n};
        $response_xml .= XMLout($data, rootname => 'perlbot-statistics');

        $connection->send_response(HTTP::Response->new(RC_OK, status_message(RC_OK),
                                                       HTTP::Headers->new(Content_Type => 'text/xml;'),
                                                       $response_xml));
      }
    }
    $connection->close;

    exit;
  }
}



sub set_topic {
  my $self = shift;
  my ($event) = @_;

  my @args = $event->args;
  $self->{_topic_cache}{$args[1]} = $args[2];
  print Dumper $self->{_topic_cache};
}


sub set_lastline {
  my $self = shift;
  my ($event) = @_;
}



1;
