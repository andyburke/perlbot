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

  $self->want_fork(0);
  $self->want_msg(0);

  $self->{_topics} = {};

  # remember we get a 'topic' even on channel joins, so nothing extra is
  # needed to capture the initial topic. (note it's a 'server' type event)
  $self->hook_event('topic', \&set_topic);
  # ('topicinfo' tells us *who* set the topic, should anyone want to grab that too)

  $self->hook_web('stats', \&stats, 'Bot Stats');

}

sub stats {
  my $self = shift;
  my @args = @_;

  if(!scalar @args) {
    my $response = "<html><head><title>Bot Stats</title></head><body><ul><li><a href=\"/stats/html\">HTML Stats</a><li><a href=\"/stats/xml\">XML Stats</a></body></html>";

    return ('text/html', $response);
  }

  if($args[0] eq 'html') {
    my $response = "<html><head><title>Bot Stats</title></head><body>";

    $response .= "<p>Perlbot " . $Perlbot::VERSION . " by " . $Perlbot::AUTHORS;
    $response .= "<br>Known Users: " . scalar keys(%{$self->perlbot->users});
    $response .= "<br>Active Channels: " . scalar keys(%{$self->perlbot->channels});
    $response .= "<br>Active Plugins: " .  scalar @{$self->perlbot->plugins};
    $response .= "<br>Uptime: " . $self->perlbot->humanreadableuptime();

    $response .= "<p><b>Channels:</b>";
    $response .= "<table width=100% border=1>";

    foreach my $channel (values %{$self->perlbot->channels}) {
      $response .= "<tr><table width=100% border=1><th width=20%>Name</th><th>Topic</th></tr>";
      $response .= "<tr><td>" . $channel->name() . "</td><td>" . $self->{_topics}{$channel->name()} . "</td></tr>";
      $response .= "<tr><th colspan=2>Members (" . scalar keys(%{$channel->{members}}) . ")</th></tr><tr><td colspan=2><ul>";
      foreach my $member (keys(%{$channel->{members}})) {
        $response .= "<li>$member";
      }
      $response .= "</ul></td></tr>";
      $response .= "<tr><th colspan=2>Status:</th></tr><tr><td colspan=2>";
      $response .= "<ul>";
      $response .= "<li>Logging: " . $channel->logging();
      $response .= "<li>Limit: " . $channel->limit();
      $response .= "<li>Default Flags: " . $channel->flags();
      $response .= "</ul></td></tr>";

      $response .= "</table></tr>";
    }


    $response .= "</table></body></html>";

    return ('text/html', $response);

  } elsif($args[0] eq 'xml') {
    my $data = {};
    
    $data->{bot} = {version => $Perlbot::VERSION,
                    authors => $Perlbot::AUTHORS,
                    knownusers => scalar keys(%{$self->perlbot->users}),
                  activechannels => scalar keys(%{$self->perlbot->channels}),
                    activeplugins => scalar @{$self->perlbot->plugins}};
    
    foreach my $channel (values %{$self->perlbot->channels}) {
      $chan_data = {name => $channel->name, topic => $self->{_topics}{$channel->name}, member => [ keys(%{$channel->{members}}) ], logging => $channel->logging, limit => $channel->limit, flags => $channel->flags};
      push @{$data->{channel}}, $chan_data;
    }
    
    $data->{uptime} = {value => $self->perlbot->uptime(),
                       humanreadable => $self->perlbot->humanreadableuptime()};
    
    my $response_xml = qq{<?xml version="1.0"?>\n};
    $response_xml .= XMLout($data, rootname => 'perlbot-statistics');
    
    return ('text/xml', $response_xml);
  } else {
    return (undef, undef); # 404
  }
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










