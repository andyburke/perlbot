package Perlbot::Plugin::Seen;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;
  
  $self->want_fork(0);

  $self->{seen} = {};
  $self->{expiretime} = 172800; # 48 hours of history

  $self->hook('seen', \&seen);
  $self->hook_event('public', \&updater);
}

sub seen {
  my $self = shift;
  my $user = shift;
  my $name = shift;

  if(defined($self->{seen}{$name})) {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($self->{seen}{$name}{seentime});

    $self->reply("$name last seen on " . ++$mon . "/$mday at $hour:$min:$sec saying '$self->{seen}{$name}{lasttext}'");
  } else {
    $self->reply("I haven't seen $name");
  }
}

sub updater {
  my $self = shift;
  my $event = shift;

  my $user = $self->{perlbot}->get_user($event->from());

  if($user) {
    $self->{seen}{$user->{name}} = {seentime => time(), lasttext => $event->{args}[0]};
  }

  $self->{seen}{$event->{nick}} = {seentime => time(), lasttext => $event->{args}[0]};

  my $curtime = time();
  foreach my $name (keys(%{$self->{seen}})) {
    if($curtime - $self->{seen}{$name}{seentime} > $self->{expiretime}) {
      delete $self->{seen}{$name};
    }
  }
}

1;
