package Perlbot::Logs::Event;

use strict;

use Perlbot;
use Perlbot::Utils;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(rawevent time type nick channel target userhost text);

sub new {
  my ($class, $rawevent, $channel) = @_;

  my $self = fields::new($class);

  $self->rawevent = $rawevent;
  $self->parse_rawevent($channel);

  return $self;
}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  debug("Got call for field: $field", 15);

  if (!exists($FIELDS{$field})) {
    die "AUTOLOAD: no such method/field '$field'";
  }

  $self->{$field};
}

sub parse_rawevent() {
  my $self = shift;
  my $channel = shift;

  my $event = $self->rawevent;
  my $eventclass = ref($event);

  if (!$eventclass) { # scalar
    $self->time = ctime_from_perlbot_date_string($event);

    $event =~ s/^.*?\s//; # eat the date off it

    ($self->channel) = $event =~ /^(.*?)\s/;
    $event =~ s/^.*?\s//; # eat the channel off

    ($self->type) = $event =~ /^\[(.*?)\]/;
    $self->type = lc($self->type);
    $event =~ s/\[.*?\]\s//; # eat off the type

    if ($self->type eq 'public') {
      ($self->nick, $self->text) = $event =~ /^<(.*?)> (.*)$/;
    } elsif($self->type eq 'caction') {
      ($self->nick, $self->text) = $event =~ /^\* (.*?) (.*)$/;
    } elsif($self->type eq 'mode') {
      ($self->nick, $self->text) = $event =~ /^(.*?) set mode\: (.*)$/;
    } elsif($self->type eq 'topic') {
      ($self->nick, $self->text) = $event =~ /^(.*?)\: (.*)$/;
    } elsif($self->type eq 'nick') {
      ($self->nick, $self->text) = $event =~ /^(.*?) changed nick to\: (.*)$/;
    } elsif($self->type eq 'quit') {
      ($self->nick, $self->text) = $event =~ /^(.*?) quit\: (.*)$/;
    } elsif($self->type eq 'kick') {
      ($self->target, $self->nick, $self->text) = $event =~ /^(.*?) was kicked by (.*?) \((.*?)\)$/;
    } elsif($self->type eq 'join') {
      ($self->nick, $self->userhost) = $event =~ /^(.*?) \((.*?)\)/;
    } elsif($self->type eq 'part') {
      ($self->nick, $self->userhost) = $event =~ /^(.*?) \((.*?)\)/;
    }

  } elsif ($eventclass eq 'Net::IRC::Event') { # a Net::IRC event
    $self->time = time();
    $self->type = $event->type;
    $self->nick = $event->nick;
    $self->channel = $channel;
    $self->text = $event->{args}[0];
    $self->userhost = $event->userhost;

    # why can't irc be sane?

    if ($self->type eq 'mode') {
      $self->text = join(' ', @{$event->{args}});
    } elsif ($self->type eq 'kick') {
      $self->target = $event->{to}[0];
      $self->text = $event->{args}[1];
    }

  } elsif ($eventclass eq 'Perlbot::Logs::Event') { # our internal spec event
    $self->time = $event->time;
    $self->type = $event->type;
    $self->nick = $event->nick;
    $self->channel = $event->channel;
    $self->target = $event->target;
    $self->userhost = $event->userhost;
    $self->text = $event->text;

  } elsif ($eventclass eq 'HASH') { # hash of values
    foreach my $key (keys(%{$event})) {
      $self->$key = $event->{$key};
    }
  }
}

sub as_string {
  my $self = shift;
  my $date = perlbot_date_string($self->time);
  my $channel = $self->channel;
  my $type = uc($self->type);
  my $nick = $self->nick;
  my $userhost = $self->userhost;
  my $target = $self->target;
  my $text = $self->text;

  my $result = "$date $channel [$type] ";

  if($self->type eq 'public') {
    $result .= "<$nick> $text";
  } elsif($self->type eq 'caction') {
    $result .= "* $nick $text";
  } elsif($self->type eq 'mode') {
    $result .= "$nick set mode: $text";
  } elsif($self->type eq 'topic') {
    $result .= "$nick: $text";
  } elsif($self->type eq 'nick') {
    $result .= "$nick changed nick to: $text";
  } elsif($self->type eq 'quit') {
    $result .= "$nick quit: $text";
  } elsif($self->type eq 'kick') {
    $result .= "$target was kicked by $nick ($text)";
  } elsif($self->type eq 'join') {
    $result .= "$nick ($userhost) joined $channel";
  } elsif($self->type eq 'part') {
    $result .= "$nick ($userhost) left $channel";
  }

  return $result;

}

sub as_string_formatted {
  my $self = shift;
  my $format = shift;

  my $date = perlbot_date_string($self->time);
  my ($year, $mon, $day, $hour, $min, $sec) = $date =~ /(\d\d\d\d)\/(\d\d)\/(\d\d)-(\d\d)\:(\d\d)\:(\d\d)/;
  my $channel = $self->channel || '';
  my $type = uc($self->type) || '';
  my $nick = $self->nick || '';
  my $userhost = $self->userhost || '';
  my $target = $self->target || '';
  my $text = $self->text || '';

  study $format;

  $format =~ s/%timestamp/$date/g;
  $format =~ s/%year/$year/g;
  $format =~ s/%mon/$mon/g;
  $format =~ s/%day/$day/g;
  $format =~ s/%hour/$hour/g;
  $format =~ s/%min/$min/g;
  $format =~ s/%sec/$sec/g;
  $format =~ s/%channel/$channel/g;
  $format =~ s/%type/$type/g;
  $format =~ s/%nick/$nick/g;
  $format =~ s/%userhost/$userhost/g;
  $format =~ s/%target/$target/g;
  $format =~ s/%text/$text/g;

  return $format;
}


sub DESTROY {
}

1;
