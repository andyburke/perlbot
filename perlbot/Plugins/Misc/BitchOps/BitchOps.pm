package Perlbot::Plugin::BitchOps;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot::Utils;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_msg(0);
  $self->want_fork(0);

  $self->hook_event('mode', \&modechange);
}

sub modechange {
  my $self = shift;
  my $event = shift;
  my $modeline = shift @{$event->{args}};
  my @nicks = @{$event->{args}}; pop @nicks; # stupid irc
  my $channel = normalize_channel($event->{to}[0]);

  if($modeline !~ /o/) { return; }

  while ($modeline !~ /^([+-][a-z])+$/) {
    $modeline =~ s/([+-])([a-z])([a-z])/$1$2$1$3/;
  }

  my @modes = $modeline =~ /([+-][a-z])/g;

  my %modehash;
  @modehash{@nicks} = @modes;

  foreach my $nick (keys(%modehash)) {
    my $validop = 0;
      
    if($nick eq $self->perlbot->curnick) { next; } #heh

    if($modehash{$nick} eq '+o') {
      foreach my $user (values(%{$self->perlbot->users})) {
        if(($user->curnick eq $nick)
           && $self->perlbot->channels->$channel->is_op($user)) {
          $validop = 1;
          next;
        }
      }
    }
    if(!$validop) {
      $self->perlbot->deop($channel, $nick);
    }
  }
}

1;
