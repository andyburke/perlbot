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
  $self->hook_event('topicinfo', \&set_topic_info);
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

    foreach my $channel (values %{$self->perlbot->channels}) {
      my $topic = '';
      my $topicsetter = '';
      if(defined(@{$self->{_topics}{$channel->name()}})) {
        ($topic, $topicsetter) = @{$self->{_topics}{$channel->name()}};
      }
      $topic =~ s/\</\&lt\;/g; $topic =~ s/\>/\&gt\;/g;
      $response .= "<p><table width=100% border=1><th width=20%>Name</th><th>Topic (set by $topicsetter)</th></tr>";
      $response .= "<tr><td>" . $channel->name() . "</td><td>$topic</td></tr>";
      $response .= "<tr><th colspan=2>Members (" . scalar keys(%{$channel->{members}}) . ")</th></tr><tr><td colspan=2><ul>";
      foreach my $member (sort(keys(%{$channel->{members}}))) {
        $response .= "<li>$member";
      }
      $response .= "</ul></td></tr>";
      $response .= "<tr><th colspan=2>Status:</th></tr><tr><td colspan=2>";
      $response .= "<ul>";
      $response .= "<li>Logging: " . $channel->logging();
      $response .= "<li>Limit: " . $channel->limit();
      $response .= "<li>Default Flags: " . $channel->flags();
      $response .= "</ul></td></tr>";

      $response .= "</table>";
    }


    $response .= "</body></html>";

    return ('text/html', $response);

  } elsif($args[0] eq 'xml') {
    my $data = {};
    
    $data->{bot} = {version => $Perlbot::VERSION,
                    authors => $Perlbot::AUTHORS,
                    knownusers => scalar keys(%{$self->perlbot->users}),
                  activechannels => scalar keys(%{$self->perlbot->channels}),
                    activeplugins => scalar @{$self->perlbot->plugins}};
    
    foreach my $channel (values %{$self->perlbot->channels}) {
      $chan_data = {name => $channel->name, topic => { text => $self->{_topics}{$channel->name}[0], nick => $self->{_topics}{$channel->name}[1] }, member => [ keys(%{$channel->{members}}) ], logging => $channel->logging, limit => $channel->limit, flags => $channel->flags};
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
  my ($channel, $topic, $nick) = (undef, undef, undef);
  if ($event->format eq 'server') {
    $channel = $args[1];
    $topic = $args[2];
  } elsif ($event->format eq 'topic') {
    $channel = $event->to->[0];
    $topic = $args[0];
    $nick = $event->nick;
  } else {
    debug("StatsServer: unexpected event format");
  }
  $topic =~ s/ $//; # strip trailing space
  $self->{_topics}{$channel} = [$topic, $nick];
}

sub set_topic_info {
  my $self = shift;
  my $event = shift;

  if($event->format ne 'server') {
    return;
  }

  my @args = $event->args;
  my $channel = $args[1];
  my ($topic, $nick) = @{$self->{_topics}{$channel}};

  $nick = $args[2];

  $self->{_topics}{$channel} = [$topic, $nick];
}


1;










