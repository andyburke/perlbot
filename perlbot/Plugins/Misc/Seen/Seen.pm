package Perlbot::Plugin::Seen;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use DB_File;

sub init {
  my $self = shift;
  
  $self->want_fork(0);

  tie %{$self->{seen}},  'DB_File', File::Spec->catfile($self->{directory}, 'seendb'), O_CREAT|O_RDWR, 0640, $DB_HASH;

  $self->{expiretime} = 172800; # 48 hours of history

  $self->hook('seen', \&seen);
  $self->hook_event('public', \&updater);
  $self->hook_event('join', \&updater);
  $self->hook_event('part', \&updater);
  $self->hook_event('quit', \&updater);
  $self->hook_event('nick', \&updater);
}

sub seen {
  my $self = shift;
  my $user = shift;
  my $name = shift;

  ($name) = split(' ', $name);

  if(defined($self->{seen}{$name})) {
    my ($lastseentime, $type, $lasttext) = split(':', $self->{seen}{$name}, 3);
    $lastseentime = scalar(localtime($lastseentime));

    my $replystring = "$name last seen on ${lastseentime} ";

    if($type eq 'PUBLIC') {
      $replystring .= "saying '${lasttext}'";
    } elsif($type eq 'JOIN') {
      $replystring .= "joining $lasttext";
    } elsif($type eq 'PART') {
      $replystring .= "leaving $lasttext";
    } elsif($type eq 'NICK') {
      $replystring .= "changing their nick to $lasttext";
    } elsif($type eq 'QUIT') {
      $replystring .= "quitting with quit message '${lasttext}'";
    }
    $self->reply($replystring);
  } else {
    $self->reply("I haven't seen ${name}!");
  }
}

sub updater {
  my $self = shift;
  my $event = shift;

  my $user = $self->{perlbot}->get_user($event->from());

  if($event->{type} eq 'public') {
    if($user) {
      $self->{seen}{$user->{name}} = time() . ':' . 'PUBLIC:' . $event->{args}[0];
    }
    $self->{seen}{$event->{nick}} = time() . ':' . 'PUBLIC:' . $event->{args}[0];
  } elsif($event->{type} eq 'join') {
    if($user) {
      $self->{seen}{$user->{name}} = time() . ':' . 'JOIN:' . $event->{to}[0];
    }
    $self->{seen}{$event->{nick}} = time() . ':' . 'JOIN:' . $event->{to}[0];
  } elsif($event->{type} eq 'part') {
    if($user) {
      $self->{seen}{$user->{name}} = time() . ':' . 'PART:' . $event->{to}[0];
    }
    $self->{seen}{$event->{nick}} = time() . ':' . 'PART:' . $event->{to}[0];
  } elsif($event->{type} eq 'nick') {
    if($user) {
      $self->{seen}{$user->{name}} = time() . ':' . 'NICK:' . $event->{args}[0];
    }
    $self->{seen}{$event->{nick}} = time() . ':' . 'NICK:' . $event->{args}[0];
  } elsif($event->{type} eq 'quit') {
    if($user) {
      $self->{seen}{$user->{name}} = time() . ':' . 'QUIT:' . $event->{args}[0];
    }
    $self->{seen}{$event->{nick}} = time() . ':' . 'QUIT:' . $event->{args}[0];
  }

  my $curtime = time();
  foreach my $name (keys(%{$self->{seen}})) {
    my ($lastseentime, $lasttext) = split(':', $self->{seen}{$name}, 2);
    if($curtime - $lastseentime > $self->{expiretime}) {
      delete $self->{seen}{$name};
    }
  }
}

1;
