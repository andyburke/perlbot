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
  $self->hook_event('caction', \&updater);
}

sub seen {
  my $self = shift;
  my $user = shift;
  my $name = shift;

  ($name) = split(' ', $name);

  if(defined($self->{seen}{$name})) {
    my ($lastseentime, $type, $lasttext) = split(':', $self->{seen}{$name}, 3);
    my $curtime = time();
    
    $lastseentime = $curtime - $lastseentime;
    $listedvals = 0;

    my $replystring = "$name last seen ";

    my $days = int($lastseentime / (60*60*24)); $lastseentime = $lastseentime % (60*60*24);
    my $hours = int($lastseentime / (60*60)); $lastseentime = $lastseentime % (60*60);
    my $minutes = int($lastseentime / 60); $lastseentime = $lastseentime % 60;
    my $seconds = $lastseentime;

    if($days && $listedvals < 2) {
      $listedvals++;
      if($days > 1) {
        $replystring .= "$days days ";
      } else {
        $replystring .= "$days day ";
      }
    }
    if($hours && $listedvals < 2) {
      $listedvals++;
      if($hours > 1) {
        $replystring .= "$hours hours ";
      } else {
        $replystring .= "$hours hour ";
      }
    }
    if($minutes && $listedvals < 2) {
      $listedvals++;
      if($minutes > 1) {
        $replystring .= "$minutes minutes ";
      } else {
        $replystring .= "$minutes minute ";
      }
    }
    if($seconds && $listedvals < 2) {
      $listedvals++;
      if($seconds > 1) {
        $replystring .= "$seconds seconds ";
      } else {
        $replystring .= "$seconds second ";
      }
    }

    $replystring .= "ago ";

    if($type eq 'PUBLIC') {
      $replystring .= "saying '${lasttext}'";
    } elsif($type eq 'JOIN') {
      $replystring .= "joining $lasttext";
    } elsif($type eq 'PART') {
      $replystring .= "leaving $lasttext";
    } elsif($type eq 'NICK') {
      $replystring .= "changing his/her nick to $lasttext";
    } elsif($type eq 'QUIT') {
      if(${lasttext}) {
        $replystring .= "quitting, having said '${lasttext}'";
      } else {
        $replystring .= "quitting, having said nothing";
      }
    } elsif($type eq 'ACTION') {
      $replystring .= "doing '${name} ${lasttext}'";
    }

    $self->reply($replystring);
  } else {
    $self->reply_error("I haven't seen ${name}!");
  }
}

sub updater {
  my $self = shift;
  my $event = shift;
  my $nick = $event->nick;

  my $user = $self->perlbot->get_user($event->from());

  if($event->type eq 'public') {
    if($user) {
      $self->{seen}{$user->name} = time() . ':' . 'PUBLIC:' . $event->{args}[0];
    }
    $self->{seen}{$nick} = time() . ':' . 'PUBLIC:' . $event->{args}[0];
  } elsif($event->type eq 'join') {
    if($user) {
      $self->{seen}{$user->name} = time() . ':' . 'JOIN:' . $event->{to}[0];
    }
    $self->{seen}{$nick} = time() . ':' . 'JOIN:' . $event->{to}[0];
  } elsif($event->type eq 'part') {
    if($user) {
      $self->{seen}{$user->name} = time() . ':' . 'PART:' . $event->{to}[0];
    }
    $self->{seen}{$nick} = time() . ':' . 'PART:' . $event->{to}[0];
  } elsif($event->type eq 'nick') {
    if($user) {
      $self->{seen}{$user->name} = time() . ':' . 'NICK:' . $event->{args}[0];
    }
    $self->{seen}{$nick} = time() . ':' . 'NICK:' . $event->{args}[0];
  } elsif($event->type eq 'quit') {
    if($user) {
      my ($junk, $otherjunk, $lastthingsaid) = split(':', $self->{seen}{$user->name}, 3);
      $self->{seen}{$user->name} = time() . ':' . 'QUIT:' . $lastthingsaid;
    }
    my ($junk, $otherjunk, $lastthingsaid) = split(':', $self->{seen}{$event->nick}, 3);
    $self->{seen}{$nick} = time() . ':' . 'QUIT:' . $lastthingsaid;
  } elsif($event->type eq 'caction') {
    if($user) {
      $self->{seen}{$user->name} = time() . ':' . 'ACTION:' . $event->{args}[0];
    }
    $self->{seen}{$nick} = time() . ':' . 'ACTION:' . $event->{args}[0];
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
