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

use XML::Simple;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->{_topics} = {};

  # remember we get a 'topic' even on channel joins, so nothing extra is
  # needed to capture the initial topic. (note it's a 'server' type event)
  $self->hook_event('topic', \&set_topic);
  # ('topicinfo' tells us *who* set the topic, should anyone want to grab that too)

  $self->hook_web('stats', sub { $self->stats(@_) });

}

sub stats {
  my $self = shift;
  my @args = @_;

  my $data = {};

  $data->{bot} = {version => $Perlbot::VERSION,
                  authors => $Perlbot::AUTHORS,
                  knownusers => scalar keys(%{$self->perlbot->users}),
                  activechannels => scalar keys(%{$self->perlbot->channels}),
                  activeplugins => scalar @{$self->perlbot->plugins}};

  foreach my $channel (values %{$self->perlbot->channels}) {
    $chan_data = {name => $channel->name, topic => $self->{_topics}{$channel->name}};
    push @{$data->{channel}}, $chan_data;
  }
  
  $data->{uptime} = {value => $self->perlbot->uptime(),
                     humanreadable => $self->perlbot->humanreadableuptime()};

  my $response_xml = qq{<?xml version="1.0"?>\n};
  $response_xml .= XMLout($data, rootname => 'perlbot-statistics');

  return ('text/xml', $response_xml);
}

sub set_topic {
  my $self = shift;
  my ($event) = @_;

  my @args = $event->args;
  my ($channel, $topic);
  if ($event->format eq 'server') {
    $channel = $args[1];
    $topic = $args[2];
  } elsif ($event->format eq 'topic') {
    $channel = $event->to->[0];
    $topic = $args[0];
  } else {
    debug("StatsServer: unexpected event format");
  }
  $topic =~ s/ $//; # strip trailing space
  $self->{_topics}{$channel} = $topic;
}

1;
