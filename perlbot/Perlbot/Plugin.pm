# Andrew Burke   <burke@bitflood.org>
# Jeremy Muhlich <jmuhlich@bitflood.org>
#
# Plugin base class
#

package Perlbot::Plugin;

use Perlbot::Utils;
use File::Spec;

sub new {
  my $class = shift;
  my $perlbot = shift;
  my $directory = shift;
  my ($name) = $class =~ /Plugin::(.*?)$/;

  my $self = {
    name => $name,
    perlbot => $perlbot,
    directory => $directory,
    config => undef,
    helpitems => {},
    hooks => {},
    hookres => {},
    addressed_hooks => [],
    admin_hooks => {},
    advanced_hooks => {},
    event_hooks => {},
    lastcontact => '',
    lastnick => '',
    lasthost => '',
    behaviors => {}, # must initialize via want_* calls below!
  };

  bless $self, $class;

  # here we set all our desired default behavior

  $self->want_msg(1);
  $self->want_public(1);
  $self->want_action(0);
  $self->want_chat(0);
  $self->want_fork(1);
  $self->want_reply_via_msg(0);

  # try to read their config file
  # try to read their help file

  $self->{config} = new Perlbot::Config(File::Spec->catfile($self->{directory}, 'config'));
  $self->{helpitems} = $self->read_help();

  return $self;
}


# params:
#   1: behavior name
#   2: 0/1 to disable/enable the behavior, or undef to just query the
#      current value
# returns:
#   current value of the specified behavior
sub _behavior {
  my ($self, $behavior, $bool) = @_;
  if (defined $bool) {
    $self->{behaviors}{$behavior} = $bool ? 1 : undef;
  }
  return $self->{behaviors}{$behavior};
}

# adds or removes a handler based on a boolean parameter
# (just a helper for want_* that deal with wanting irc events)
# params:
#   1: event name
#   2: 0/1 to remove/add the handler (if undef, no action taken)
sub _addremove_handler {
  my ($self, $event, $bool) = @_;

  if (defined $bool) {
    if ($bool) {
      print "_addremove_handler: adding '$event' handler for '$self->{name}'\n" if $Perlbot::DEBUG >= 2;
      $self->{perlbot}->add_handler($event, sub {$self->_process(@_)}, $self->{name});
    } else {
      print "_addremove_handler: removing '$event' handler for '$self->{name}'\n" if $Perlbot::DEBUG >= 2;
      $self->{perlbot}->remove_handler($event, $self->{name});
    }
  }
}

# want to be triggered by private messages?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_msg {
  my ($self, $bool) = @_;
  $self->_addremove_handler('msg', $bool);
  $self->_behavior('msg', $bool);
}


# want to be triggered by public text?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_public {
  my ($self, $bool) = @_;
  $self->_addremove_handler('public', $bool);
  $self->_behavior('public', $bool);
}


# want to be triggered by ctcp actions?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_action {
  my ($self, $bool) = @_;
  $self->_addremove_handler('caction', $bool);
  $self->_behavior('action', $bool);
}

# want to be triggered by dcc chat msgs?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_chat {
  my ($self, $bool) = @_;
  $self->_addremove_handler('chat', $bool);
  $self->_behavior('chat', $bool);
}

# want handlers to be forked automatically?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_fork {
  my ($self, $bool) = @_;
  $self->_behavior('fork', $bool);
}

# want all replies to be sent via private msg?
# params:
#   1: 0/1 to disable/enable, or undef to just query
sub want_reply_via_msg {
  my ($self, $bool) = @_;
  $self->_behavior('reply_via_msg', $bool);
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

sub hook_event {
  my $self = shift;
  my $event = shift;
  my $call = shift;

  # push the callback onto our list for this event type
  # add a handler for the event type with our perlbot object

  push(@{$self->{event_hooks}{$event}}, $call);
  $self->{perlbot}->add_handler($event, sub {$self->_process(@_)}, $self->{name});
}

sub advanced_hook {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->{advanced_hooks}{$hook} = $call;
}

# send a reply to the bot's last contact via the correct path (msg, public, etc.)
# can take an array of lines to send
sub reply {
  my $self = shift;
  my @text = @_;
  my @output;

  # foreach line of the array we were passed
  #   split that line up if it has a newline in it
  #   add it all to the output

  foreach my $textline (@text) {
    my @lines = split('\n', $textline);
    push(@output, @lines);
  }

  # if the admin set a max public reply lines and our output is too big
  #   send the output via msg
  # else
  #   send the output via whatever method it came in by

  if($self->{perlbot}->config->value(bot => max_public_reply_lines) &&
     @output > $self->{perlbot}->config->value(bot => max_public_reply_lines)) {
    foreach my $line (@output) {
      $self->{perlbot}->msg($self->{lastnick}, $line);
    }
  } else {
    foreach my $line (@output) {
      $self->{perlbot}->msg($self->{lastcontact}, $line);
    }
  }
}

sub reply_via_msg {
  my $self = shift;
  my @text = @_;
  my @output;

  # see reply

  foreach my $textline (@text) {
    my @lines = split('\n', $textline);
    push(@output, @lines);
  }

  # send reply via msg

  foreach my $line (@output) {
    $self->{perlbot}->msg($self->{lastnick}, $line);
  }
}

sub reply_error {
  my $self = shift;
  my @text = @_;
  my @output;

  # see reply

  foreach my $textline (@text) {
    my @lines = split('\n', $textline);
    push(@output, @lines);
  }

  # if the admin said to send errors via msg
  #   send the error via message
  # else
  #   send the error back in whatever way we got it

  if($self->{perlbot}->config->value(bot => send_errors_via_msg)) {
    foreach my $line (@output) {
      $self->{perlbot}->msg($self->{lastnick}, $line);
    }
  } else {
    foreach my $line (@output) {
      $self->{perlbot}->msg($self->{lastcontact}, $line);
    }
  }
}

sub addressed_reply {
  my $self = shift;
  my @text = @_;
  my @output;

  # see reply

  foreach my $textline (@text) {
    my @lines = split('\n', $textline);
    push(@output, @lines);
  }

  # adds a preceding nickname to our output, see reply

  if($self->{perlbot}->config->value(bot => max_public_reply_lines) &&
     @output > $self->{perlbot}->config->value(bot => max_public_reply_lines)) {
    foreach my $line (@output) {
      $self->{perlbot}->msg($self->{lastnick}, $self->{lastnick} . ', ' . $line);
    }
  } else {
    foreach my $line (@output) {
      $self->{perlbot}->msg($self->{lastcontact}, $self->{lastnick} . ', ' . $line);
    }
  }
}

sub _help {
  my $self = shift;
  my $command = shift;
  my @result;

  # if the command we're looking for is actually this plugin's name
  #   if we have an overview defined
  #     send back the overview
  #     send back a list of our available commands
  # else if we have help for the command they're looking for
  #   send back the help content for that command
  # return our (possibly empty) result

  if($command eq $self->{name}) {
    if($self->{helpitems}{overview}[0]) {
      push(@result, @{$self->{helpitems}{overview}});
      push(@result, 'Available commands:');
      push(@result, join(' ', keys(%{$self->{helpitems}{command}})));
    }
  } elsif($self->{helpitems}{command}{$command}) {
    push(@result, @{$self->{helpitems}{command}{$command}{content}});
  }

  return @result;
}

sub _process { # _process to stay out of people's way
  my $self  = shift;
  my $event = shift;
  my $user  = shift;
  my $text  = shift;

  # if the type of event isn't a message and this channel has an ignoreplugins
  # list, and the current plugin is listed in that list, return without doing
  # anything
  my $chan_name = normalize_channel($event->{to}[0]);
  if ($event->type ne 'msg' and
      $self->{perlbot}->config->value(channel => $chan_name => 'ignoreplugin') and
      grep {$_ eq $self->{name}}
           @{$self->{perlbot}->config->value(channel => $chan_name => 'ignoreplugin')}) {
    return;
  }

  $text ||= '';

  # set a couple of history things for our reply* methods

  $self->{lastnick} = $event->nick;
  $self->{lasthost} = $event->host;

  # foreach normal hook we have
  #   append the command prefix to it
  #   if the event's text matches our hook
  #     strip the hook from the event's text
  #     if the event was a message or this plugins should reply via msg
  #       set our last contact to the nick of the person generating the event
  #     else
  #       set our last contact to the channel this event came from
  #     dispatch this event to the appropriate handler with the right args

  foreach my $hook (keys(%{$self->{hooks}})) {
    my $regexp = $self->{perlbot}->config->value(bot => 'commandprefix') . $hook;
    if($text =~ /^\Q${regexp}\E?(?:\s+|$)/i) {
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

  # like above, but with a raw regular expression

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
  
  # like above, but here we can return any event in which the bot was addressed

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

  # just like the first one, but with an added check to make sure the
  # person generating the event is an admin

  foreach my $admin_hook (keys(%{$self->{admin_hooks}})) {
    my $regexp = $self->{perlbot}->config->value(bot => 'commandprefix') . $admin_hook;
    if($text =~ /^\Q${regexp}\E(?:\s+|$)/i) {
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
        $self->{perlbot}->msg($event->nick(), 'You are not an admin!');
      }
    }
  }

  # here we just return the event in addition to the other stuff

  foreach my $advanced_hook (keys(%{$self->{advanced_hooks}})) {
    my $regexp = $self->{perlbot}->config->value(bot => 'commandprefix') . $advanced_hook;
    if($text =~ /^\Q${regexp}\E(?:\s+|$)/i) {
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

  # here we just return raw events

  foreach my $event_hook (@{$self->{event_hooks}{$event->type()}}) {
    if($event->type() eq 'msg' || $self->{behaviors}{reply_via_msg}) {
      $self->{lastcontact} = $event->nick();
    } else {
      $self->{lastcontact} = $event->{to}[0];
    }

    $self->_dispatch($event_hook, $event);
  }
}


# Calls the given coderef as a method of $self and passes some params.
# Forks if the 'fork' behavior is true.
sub _dispatch {
  my ($self, $coderef, @params) = @_;
  my ($pid);

  # if this plugin wants to fork
  #   if we couldn't fork
  #     tell the user
  #     return
  #   if we're the parent
  #     ignore our children
  #   else (we're the child)
  #     call the coderef we were given with the params
  #     empty any events on the queue
  #     set ourself to not be connected
  #     exit
  # else
  #   just send the event without forking

  if ($self->want_fork) {

    if (!defined($pid = fork)) {
      $self->reply_error("fork error in $self->{name} plugin");
      return;
    }

    if ($pid) {
      # parent
      $SIG{CHLD} = IGNORE; #sub { wait };
    } else {
      # child
      $coderef->($self, @params);
      $self->{perlbot}->empty_queue; # send all waiting events
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


sub config {
  my ($self) = @_;

  return $self->{config};
}


sub read_help {
  my $self = shift;
  my $filename = shift;
  $filename ||= 'help.xml';

  return read_generic_config(File::Spec->catfile($self->{directory}, $filename));
}

1;
