package Perlbot::Plugin::UserUpdater;

use Perlbot::Utils;
use Perlbot;
use Perlbot::User;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

our $VERSION;

sub init {
  my $self = shift;

  $self->want_fork(0);

  $self->hook_event('public', \&update);
  $self->hook_event('msg', \&update);
  $self->hook_event('caction', \&update);
  $self->hook_event('join', \&update);
  $self->hook_event('part', \&update);
  $self->hook_event('mode', \&update);
  $self->hook_event('topic', \&update);
  $self->hook_event('nick', \&update);
  $self->hook_event('quit', \&update);
  $self->hook_event('kick', \&update);
  $self->hook_event('namreply', \&update);

}

# ============================================================
# event handlers
# ============================================================

sub update {
  my $self = shift;
  my $event = shift;

  my $userhost = $event->from;
  my $type = $event->type;
  my $nick = $event->nick;
  my $channel = normalize_channel($event->{to}[0]);
  my $chan = $self->perlbot->get_channel($channel);
  my $text = $event->{args}[0];
  my $user = $self->perlbot->get_user($userhost);

  if ($type eq 'join' and $chan) {
    $chan->add_member($nick);
  }

  if ($type eq 'part' and $chan) {
    $chan->remove_member($nick);
  }

  if ($type eq 'quit') {
    # FIXME: consider a solution like plugins being able to defer
    # here we delay removing them from the channel member list so that the logger
    # can log their quit.
    $self->perlbot->schedule(1, sub { $self->delayed_quit_remove($nick); });
  }

  if ($type eq 'nick') {
    foreach my $chan (values(%{$self->perlbot->channels})) {
      if($chan->is_member($nick)) {
        $chan->remove_member($nick);
        $chan->add_member($event->{args}[0]);
      }
    }
  }

  if ($type eq 'kick') {
    my $chan = $self->perlbot->get_channel($event->{args}[0]);
    if ($chan) {
      $chan->remove_member($nick);
    }
  }

  if ($type eq 'namreply') {
    my $chan = $self->perlbot->get_channel($event->{args}[2]);
    my $nickstring = $event->{args}[3];
    my @nicks = split(' ', $nickstring);
    if (defined($chan)) {
      $chan->clear_member_list();
      $chan->clear_currentopped_list();
      foreach my $nick (@nicks) {
        my $curop;
        $curop = 1 if ($nick =~ /^@/);
        $nick =~ s/^@//;
        $chan->add_current_op($nick) if $curop;
        $chan->add_member($nick);
      }
    }
  }

  if ($type eq 'mode') {
    my $chan = $self->perlbot->get_channel($event->{to}[0]);
    my $modeline = $event->{args}[0];
    my @nicks = @{$event->{args}}; shift @nicks; pop @nicks; # this is jus confusing

    $chan or return;

    if ($modeline =~ /[ov]/) {
      while ($modeline !~ /^([+-][a-z])+$/) {
        $modeline =~ s/([+-])([a-z])([a-z])/$1$2$1$3/;
      }

      my @modes = $modeline =~ /([+-][a-z])/g;
      
      my %modehash;
      @modehash{@nicks} = @modes;
      
      while (my($nick,$mode) = each (%modehash)) {
        if ($mode eq '-o') {
          $chan->remove_current_op($nick);
        } elsif ($mode eq '+o') {
          $chan->add_current_op($nick);
        }
      }
    }
  } 

  if ($user) {
    $user->curnick = $nick;
  }

  return $user;

}

sub delayed_quit_remove {
  my $self = shift;
  my $nick = shift;

  foreach my $channel (values(%{$self->perlbot->channels})) {
    $channel->remove_member($nick);
  }
}

1;








