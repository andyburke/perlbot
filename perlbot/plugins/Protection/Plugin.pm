package Protection::Plugin;

use Plugin;
@ISA = qw(Plugin);

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->{config} = $self->read_config();
  $self->{deoppers} = {};

  $self->{perlbot}->add_handler('mode', sub {$self->modechange(@_) }, $self->{name});
}

sub modechange {
  my $self = shift;
  my $event = shift;
  my $modestring = $event->{args}[0];

  my $deopper = $event->nick();

  if($deopper eq $self->{perlbot}{curnick}) { return; }

  if($modestring =~ /-o/) {
    my $numdeops = length(($modestring =~ /-(o+)/g)[0]);

    if($numdeops > 1 && $self->{config}{mintimebetweendeops}[0] > 0) {
      $self->{perlbot}->deop($event->{to}[0], $event->nick());
    } elsif($self->{deoppers}{$deopper} &&
            (time() - $self->{deoppers}{$event->nick()}) < $self->{config}{mintimebetweendeops}[0]) {
      $self->{perlbot}->deop($event->{to}[0], $event->nick());
    }

    $self->{deoppers}{$event->nick()} = time();

    foreach my $deopper (keys(%{$self->{deoppers}})) {
      if(time() - $self->{deoppers}{$deopper} > $self->{config}{mintimebetweendeops}[0]) {
        delete $self->{deoppers}{$deopper};
      }
    }
  }
}

1;



