# Jeremy Muhlich <jmuhlich@bitflood.org>
#
# Based on LogServer.pm by (mainly) Andrew Burke.
#
# TODO: make it use channel keys for password protection of the stats... ?
#       make this thing die cleanly
#       fork-at-birth not going to work here, bad idea anyway. set timeout?
$       split up plugin forking logic so we can re-use parts here

package Perlbot::Plugin::StatsServer;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot::Utils;

use HTTP::Daemon;
use HTTP::Response;
use HTTP::Headers;
use XML::Simple;

our $VERSION = '1.0.0';

sub new {
  my $self = Perlbot::Plugin->new(@_);

  my $server = HTTP::Daemon->new(LocalAddr => $self->config->value(server => 'hostname'),
                                 LocalPort => $self->config->value(server => 'port'));

  if (!$server) {
    debug("Could not create StatsServer http server: $!");
    return undef;
  }

  return $self;
}

sub init {
  my $self = shift;

  $self->want_msg(0);

  $self->hook_event('endofmotd', sub { $self->statsserver });
  $self->hook_event('nomotd', sub { $self->statsserver });
  $self->hook_event('topic', sub { $self->set_topic });
  $self->hook(sub { $self->set_lastline });

}

sub handle_request {
  my $self = shift;

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
          $chan_data = {name => $channel->name};
          push @{$data->{channel}}, $chan_data;
        }

        my $response_xml = XMLout($data, rootname => 'perlbot-statistics');

        $connection->send_response(HTTP::Response->new(HTTP::Response::RC_OK,
                                                       'yay!',
                                                       HTTP::Headers->new(Content_Type => 'text/xml;'),
                                                       $response_xml));
      }
    }
    $connection->close;

    $self->perlbot->empty_queue; # send all waiting events
    $self->_shutdown();
    $self->perlbot->shutdown();
  }
}



sub set_topic {
  my $self = shift;
}


sub set_lastline {
  my $self = shift;
}



1;
