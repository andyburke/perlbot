# Andrew Burke   <burke@bitflood.org>
# Jeremy Muhlich <jmuhlich@bitflood.org>
#
# Plugin base class
#

package Plugin;

use PerlbotUtils;

sub new {
  my $class = shift;
  my $perlbot = shift;
  my $directory = shift;
  my ($name) = $class =~ /^(.*?)::Plugin/;

  my $self = {
    name => $name,
    perlbot => $perlbot,
    directory => $directory,
    hooks => {},
    hookres => {},
    addressed_hooks => [],
    admin_hooks => {},
    advanced_hooks => {},
    lastcontact => '',
    lastnick => '',
    lasthost => '',
    behaviors => {
      msg => 1, public => 1, action => 0, chat => 0,
      fork => 1, reply_via_msg => 0
    },
  };

  bless $self, $class;


  $self->{perlbot}->add_handler('msg',     sub {$self->_process(@_)}, $self->{name});
  $self->{perlbot}->add_handler('public',  sub {$self->_process(@_)}, $self->{name});
  $self->{perlbot}->add_handler('caction', sub {$self->_process(@_)}, $self->{name});
  $self->{perlbot}->add_handler('chat',    sub {$self->_process(@_)}, $self->{name});
  return $self;
}


# params:
#   1: behavior name
#   2: 0/1 to disable/enable the behavior, or undef to just query the
#      current value
# returns:
#   current value of the specified behavior
sub behavior {
  my ($self, $behavior, $bool) = @_;
  if (defined $bool) {
    $self->{behaviors}{$behavior} = $bool ? 1 : undef;
  }
  return $self->{behaviors}{$behavior};
}


# want to be triggered by private messages?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_msg {
  my ($self, $bool) = @_;
  $self->behavior('msg', $bool);
}


# want to be triggered by public text?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_public {
  my ($self, $bool) = @_;
  $self->behavior('public', $bool);
}


# want to be triggered by ctcp actions?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_action {
  my ($self, $bool) = @_;
  $self->behavior('action', $bool);
}

# want to be triggered by dcc chat msgs?
sub want_chat {
  my ($self, $bool) = @_;
  $self->behavior('chat', $bool);
}

# want handlers to be forked automatically?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_fork {
  my ($self, $bool) = @_;
  $self->behavior('fork', $bool);
}

sub want_reply_via_msg {
  my ($self, $bool) = @_;
  $self->behavior('reply_via_msg', $bool);
}


sub hook {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->{hooks}{$hook} = $call;
}


sub hook_regular_expression {
  my $self = shift;
  my $hookre = shift;
  my $call = shift;

  $self->{hookres}{$hookre} = $call;
}

sub hook_addressed {
  my $self = shift;
  my $call = shift;

  push(@{$self->{addressed_hooks}}, $call);
}

sub hook_admin {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->{admin_hooks}{$hook} = $call;
}

sub advanced_hook {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->{advanced_hooks}{$hook} = $call;
}


sub reply {
  my $self = shift;
  my $text = shift;

  my @lines = split('\n', $text);

  if($self->{perlbot}->config(bot => max_public_reply_lines) &&
     @lines > $self->{perlbot}->config(bot => max_public_reply_lines)) {
    foreach my $line (@lines) {
      $self->{perlbot}->msg($self->{lastnick}, $line);
    }
  } else {
    foreach my $line (split('\n', $text)) {
      $self->{perlbot}->msg($self->{lastcontact}, $line);
    }
  }
}

sub reply_via_msg {
  my $self = shift;
  my $text = shift;

  foreach my $line (split('\n', $text)) {
    $self->{perlbot}->msg($self->{lastnick}, $line);
  }
}

sub reply_error {
  my $self = shift;
  my $text = shift;

  if($self->{perlbot}->config(bot => send_errors_via_msg)) {
    foreach my $line (split('\n', $text)) {
      $self->{perlbot}->msg($self->{lastnick}, $line);
    }
  } else {
    foreach my $line (split('\n', $text)) {
      $self->{perlbot}->msg($self->{lastcontact}, $line);
    }
  }
}

sub addressed_reply {
  my $self = shift;
  my $text = shift;

  foreach my $line (split('\n', $text)) {
    $self->{perlbot}->msg($self->{lastcontact}, $self->{lastnick} . ', ' . $line);
  }
}



sub _process { # _process to stay out of people's way
  my $self  = shift;
  my $event = shift;
  my $user  = shift;
  my $text  = shift;

  if($event->type eq 'msg' and !$self->want_msg) { return; }
  if($event->type eq 'public' and !$self->want_public) { return; }
  if($event->type eq 'caction' and !$self->want_action) { return; }
  if($event->type eq 'chat' and !$self->want_chat) { return; }

  $self->{lastnick} = $event->nick();
  $self->{lasthost} = $event->host();

  foreach my $hook (keys(%{$self->{hooks}})) {
    my $regexp = $self->{perlbot}->config(bot => 'commandprefix') . $hook;
    if($text =~ /^\Q${regexp}\E?(?:\s+|$)/) {
      my $texttocallwith = $text;
      $texttocallwith =~ s/^\Q${regexp}\E(?:\s+|$)//i;

      if(($event->type() eq 'msg') || $self->{behaviors}{reply_via_msg}) {
        $self->{lastcontact} = $event->nick();
      } else {
        $self->{lastcontact} = $event->{to}[0];
      }
      $self->_dispatch($self->{hooks}{$hook}, $user, $texttocallwith);
    }
  }

  foreach my $hookre (keys(%{$self->{hookres}})) {
    if($text =~ /$hookre/) {
      if($event->type() eq 'msg' || $self->{behaviors}{reply_via_msg}) {
        $self->{lastcontact} = $event->nick();
      } else {
        $self->{lastcontact} = $event->{to}[0];
      }

      $self->_dispatch($self->{hookres}{$hookre}, $user, $text);
    }
  }

  if($text =~ /^$self->{perlbot}{curnick}(?:,|:|\.|\s)*/i) {
    if($event->type() eq 'msg' || $self->{behaviors}{reply_via_msg}) {
      $self->{lastcontact} = $event->nick();
    } else {
      $self->{lastcontact} = $event->{to}[0];
    }

    my $texttocallwith = $text;
    $texttocallwith =~ s/^$self->{perlbot}{curnick}(?:,|:|\.|\s)*//i;
    foreach my $addressed_hook (@{$self->{addressed_hooks}}) {
      $self->_dispatch($addressed_hook, $user, $texttocallwith);
    }
  }

  foreach my $admin_hook (keys(%{$self->{admin_hooks}})) {
    my $regexp = $self->{perlbot}->config(bot => 'commandprefix') . $admin_hook;
    if($text =~ /^\Q${regexp}\E(?:\s+|$)/) {
      if($user && $user->is_admin()) {
        my $texttocallwith = $text;
        $texttocallwith =~ s/^\Q${regexp}\E(?:\s+|$)//i;

        if(($event->type() eq 'msg') || $self->{behaviors}{reply_via_msg}) {
          $self->{lastcontact} = $event->nick();
        } else {
          $self->{lastcontact} = $event->{to}[0];
        }
        $self->_dispatch($self->{admin_hooks}{$admin_hook}, $user, $texttocallwith);
      } else {
        $self->{perlbot}{ircconn}->privmsg($event->nick(), 'You are not an admin!');
      }
    }
  }

  foreach my $advanced_hook (keys(%{$self->{advanced_hooks}})) {
    my $regexp = $self->{perlbot}->config(bot => 'commandprefix') . $advanced_hook;
    if($text =~ /^\Q${regexp}\E(?:\s+|$)/) {
      my $texttocallwith = $text;
      $texttocallwith =~ s/^\Q${regexp}\E(?:\s+|$)//i;

      if($event->type() eq 'msg' || $self->{behaviors}{reply_via_msg}) {
        $self->{lastcontact} = $event->nick();
      } else {
        $self->{lastcontact} = $event->{to}[0];
      }
      $self->_dispatch($self->{advanced_hooks}{$advanced_hook}, $user, $event, $texttocallwith);
    }
  }
}


# Calls the given coderef as a method of $self and passes some params.
# Forks if the 'fork' behavior is true.
sub _dispatch {
  my ($self, $coderef, @params) = @_;
  my ($pid);

  if ($self->want_fork) {

    if (!defined($pid = fork)) {
      $self->reply("fork error in $self->{name} plugin");
      return;
    }

    if ($pid) {
      # parent
      $SIG{CHLD} = IGNORE; #sub { wait };
    } else {
      # child
      $coderef->($self, @params);
      # this is dirty, but nothing else makes everything happy
      $self->{perlbot}{ircconn}{_connected} = 0;
      exit;
    }

  } else {

    $coderef->($self, @params);

  }
}

sub shutdown {
  my $self = shift;

}

sub read_config {
  my $self = shift;
  my $filename = shift;
  $filename or $filename = 'config';

  return read_generic_config(File::Spec->catfile($self->{directory}, $filename));
}

sub write_config {
  my $self = shift;
  my $hash = shift;
  my $filename = shift;
  $filename or $filename = 'config';

  return write_generic_config(File::Spec->catfile($self->{directory}, $filename), $hash);
}

1;