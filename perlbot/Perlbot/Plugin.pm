# Andrew Burke   <burke@bitflood.org>
# Jeremy Muhlich <jmuhlich@bitflood.org>
#
# Plugin base class
#

package Perlbot::Plugin;

use strict;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(name perlbot directory config helpitems infoitems commandprefix_hooks addressed_command_hooks regular_expression_hooks addressed_hooks commandprefix_admin_hooks addressed_command_admin_hooks commandprefix_advanced_hooks addressed_command_advanced_hooks event_hooks lastcontact lastnick lasthost behaviors);

use Perlbot::Utils;
use Perlbot::PluginConfig;
use File::Spec;

sub new {
  my $class = shift;
  my $perlbot = shift;
  my $directory = shift;
  my ($name) = $class =~ /Plugin::(.*?)$/;

  my $self = fields::new($class);

  $self->name = $name;
  $self->perlbot = $perlbot;
  $self->directory = $directory;

  $self->config = new Perlbot::PluginConfig($self->name, $self->perlbot->config);

  $self->helpitems = $self->_read_help();
  $self->infoitems = $self->_read_info();
  
  $self->commandprefix_hooks = {};
  $self->addressed_command_hooks = {};
  $self->regular_expression_hooks = {};
  $self->addressed_hooks = [];
  $self->commandprefix_admin_hooks = {};
  $self->addressed_command_admin_hooks = {};
  $self->commandprefix_advanced_hooks = {};
  $self->addressed_command_advanced_hooks = {};
  $self->event_hooks = {};
  $self->lastcontact = '';
  $self->lastnick = '';
  $self->lasthost = '';
  $self->behaviors = {};

  # here we set all our desired default behavior

  $self->want_msg(1);
  $self->want_public(1);
  $self->want_action(0);
  $self->want_chat(0);
  $self->want_fork(1);
  $self->want_reply_via_msg(0);

  return $self;
}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  if(!exists($FIELDS{$field})) {
    return;
  }

  debug("Got call for field: $field", 15);

  $self->{$field};
}

sub init { } # stub

sub author {
  my $self = shift;
  if(defined($self->infoitems)) {
    return $self->infoitems->{'author'}[0];
  }
  return undef;
}

sub contact {
  my $self = shift;
  if(defined($self->infoitems)) {
    return $self->infoitems->{'contact'}[0];
  }
  return undef;
}

sub url {
  my $self = shift;
  if(defined($self->infoitems)) {
    return $self->infoitems->{'url'}[0];
  }
  return undef;
}

sub version {
  my $self = shift;
  return eval '$Perlbot::Plugin::'.$self->name.'::VERSION';
}

sub set_initial_config_values {
  # meant to be overridden
  return;
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
    $self->behaviors->{$behavior} = $bool ? 1 : undef;
  }
  return $self->behaviors->{$behavior};
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
      debug("  adding '$event' handler for '" . $self->name . "'", 3);
      $self->perlbot->add_handler($event, sub {$self->_process(@_)}, $self->name);
    } else {
      debug("  removing '$event' handler for '" . $self->name . "'", 3);
      $self->perlbot->remove_handler($event, $self->name);
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

  # if they pass just a coderef, treat it like they passed an
  # empty/undef hook and then the coderef.  i.e.,
  #   hook(\&code) is equivalent to hook(undef, \&code)
  if (ref($hook) eq 'CODE' and !defined($call)) {
    $call = $hook;
    $hook = undef;
  }

  if (defined($hook) and length($hook) > 0) {
    $self->hook_commandprefix($hook, $call);
    $self->hook_addressed_command($hook, $call);
  } else {
    $self->hook_regular_expression('.', $call);
  }
}

sub hook_commandprefix {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->commandprefix_hooks->{$hook} = $call;
}

sub hook_addressed_command {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->addressed_command_hooks->{$hook} = $call;
}

sub hook_regular_expression {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->regular_expression_hooks->{$hook} = $call;
}

sub hook_addressed {
  my $self = shift;
  my $call = shift;

  push(@{$self->addressed_hooks}, $call);
}

sub hook_admin {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->hook_commandprefix_admin($hook, $call);
  $self->hook_addressed_command_admin($hook, $call);
}

sub hook_commandprefix_admin {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->commandprefix_admin_hooks->{$hook} = $call;
}

sub hook_addressed_command_admin {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->addressed_command_admin_hooks->{$hook} = $call;
}

sub hook_event {
  my $self = shift;
  my $event = shift;
  my $call = shift;

  # push the callback onto our list for this event type
  # add a handler for the event type with our perlbot object

  push(@{$self->event_hooks->{$event}}, $call);
  $self->perlbot->add_handler($event, sub {$self->_process(@_)}, $self->name);
}

sub hook_advanced {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->hook_commandprefix_advanced($hook, $call);
  $self->hook_addressed_command_advanced($hook, $call);
}

sub hook_commandprefix_advanced {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->commandprefix_advanced_hooks->{$hook} = $call;
}

sub hook_addressed_command_advanced {
  my $self = shift;
  my $hook = shift;
  my $call = shift;

  $self->addressed_command_advanced_hooks->{$hook} = $call;
}

sub hook_web {
  my $self = shift;
  my $hook = shift;
  my $call = shift;
  my $description = shift;

  $self->perlbot->webserver_add_handler($hook, sub { $call->($self, @_) }, $description, $self->name);
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

  if($self->perlbot->config->get(bot => 'max_public_reply_lines') &&
     @output > $self->perlbot->config->get(bot => 'max_public_reply_lines')) {
    foreach my $line (@output) {
      $self->perlbot->msg($self->lastnick, $line);
    }
  } else {
    foreach my $line (@output) {
      $self->perlbot->msg($self->lastcontact, $line);
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
    $self->perlbot->msg($self->lastnick, $line);
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

  if($self->perlbot->config->get(bot => 'send_errors_via_msg')) {
    foreach my $line (@output) {
      $self->perlbot->msg($self->lastnick, $line);
    }
  } else {
    foreach my $line (@output) {
      $self->perlbot->msg($self->lastcontact, $line);
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

  if($self->perlbot->config->get(bot => 'max_public_reply_lines') &&
     @output > $self->perlbot->config->get(bot => 'max_public_reply_lines')) {
    foreach my $line (@output) {
      $self->perlbot->msg($self->lastnick, $self->lastnick . ', ' . $line);
    }
  } else {
    foreach my $line (@output) {
      $self->perlbot->msg($self->lastcontact, $self->lastnick . ', ' . $line);
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

  if($command eq $self->name) {
    my $infostring = $self->name;
    if($self->version) { $infostring .= " v" . $self->version; }
    if($self->author) { $infostring .= " by " . $self->author; }
    if($self->contact) { $infostring .= " <" . $self->contact . ">"; }
    if($self->url) { $infostring .= ", " . $self->url; }
    push(@result, $infostring);
    if(defined($self->helpitems) && defined($self->helpitems->{overview})) {
      if(ref($self->helpitems->{overview}[0]) eq 'HASH') {
        push(@result, @{$self->helpitems->{overview}[0]{content}});
      } else {
        push(@result, @{$self->helpitems->{overview}});
      }
      if(keys(%{$self->helpitems->{command}})) {
        push(@result, 'Available commands:');
        push(@result, join(' ', keys(%{$self->helpitems->{command}})));
      }
    }
  } elsif(defined($self->helpitems) && $self->helpitems->{command}{$command}) {
    if($self->helpitems->{command}{$command}{content}) {
      if(ref($self->helpitems->{command}{$command}{content}) eq 'ARRAY') {
        push(@result, @{$self->helpitems->{command}{$command}{content}});
      } else {
        push(@result, $self->helpitems->{command}{$command}{content});
      }
    }
    if($self->helpitems->{usage}{$command}{content}) {
      push(@result, "Usage: " . $self->perlbot->config->get(bot => 'commandprefix') . $self->helpitems->{usage}{$command}{content});
    }
  }

  return @result;
}

sub _process { # _process to stay out of people's way
  my $self  = shift;
  my $event = shift;
  my $user  = shift;
  my $text  = shift;
  my $botnick = $self->perlbot->curnick;

  # if the type of event isn't a message and this channel has an ignoreplugins
  # list, and the current plugin is listed in that list, return without doing
  # anything
  my $chan_name = normalize_channel($event->{to}[0]);
  if ($event->type ne 'msg' and
      grep {$_ eq $self->name}
           $self->perlbot->config->array_get(channel => $chan_name => 'ignoreplugin')) {
    return;
  }

  $text ||= '';

  # set a couple of history things for our reply* methods

  $self->lastnick = $event->nick;
  $self->lasthost = $event->host;

  # foreach normal hook we have
  #   append the command prefix to it
  #   if the event's text matches our hook
  #     strip the hook from the event's text
  #     if the event was a message or this plugins should reply via msg
  #       set our last contact to the nick of the person generating the event
  #     else
  #       set our last contact to the channel this event came from
  #     dispatch this event to the appropriate handler with the right args

  foreach my $commandprefix_hook (keys(%{$self->commandprefix_hooks})) {
    my $regexp = $self->perlbot->config->get(bot => 'commandprefix') . $commandprefix_hook;
    if($text =~ /^\Q${regexp}\E(?:\s+|$)/i) {
      my $texttocallwith = $text;
      $texttocallwith =~ s/^\Q${regexp}\E(?:\s+|$)//i;
      $self->_set_lastcontact($event);
      $self->_dispatch($self->commandprefix_hooks->{$commandprefix_hook}, $user, $texttocallwith, $event);
    }
  }

  foreach my $addressed_command_hook (keys(%{$self->addressed_command_hooks})) {
    my $regexp = $botnick . '(?:,|:|\.|\s)*' . $self->perlbot->config->get(bot => 'commandprefix') . '*' . $addressed_command_hook . '(?:\s+|$)';
    if($text =~ /^${regexp}/i) {
      my $texttocallwith = $text;
      $texttocallwith =~ s/${regexp}//i;
      $self->_set_lastcontact($event);
      $self->_dispatch($self->addressed_command_hooks->{$addressed_command_hook}, $user, $texttocallwith, $event);
    }
  }

  # like above, but with a raw regular expression

  foreach my $regular_expression_hook (keys(%{$self->regular_expression_hooks})) {
    if($text =~ /$regular_expression_hook/) {
      $self->_set_lastcontact($event);
      $self->_dispatch($self->regular_expression_hooks->{$regular_expression_hook}, $user, $text, $event);
    }
  }
  
  # like above, but here we can return any event in which the bot was addressed

  if($text =~ /^$botnick(?:,|:|\.|\s)*/i) {
    $self->_set_lastcontact($event);
    my $texttocallwith = $text;
    $texttocallwith =~ s/^$botnick(?:,|:|\.|\s)*//i;
    foreach my $addressed_hook (@{$self->addressed_hooks}) {
      $self->_dispatch($addressed_hook, $user, $texttocallwith, $event);
    }
  }

  # just like the first one, but with an added check to make sure the
  # person generating the event is an admin

  foreach my $commandprefix_admin_hook (keys(%{$self->commandprefix_admin_hooks})) {
    my $regexp = $self->perlbot->config->get(bot => 'commandprefix') . $commandprefix_admin_hook;
    if($text =~ /^\Q${regexp}\E(?:\s+|$)/i) {
      if($user && $self->perlbot->is_admin($user)) {
        my $texttocallwith = $text;
        $texttocallwith =~ s/^\Q${regexp}\E(?:\s+|$)//i;
        $self->_set_lastcontact($event);
        $self->_dispatch($self->commandprefix_admin_hooks->{$commandprefix_admin_hook}, $user, $texttocallwith, $event);
      } else {
        $self->perlbot->msg($event->nick(), 'You are not an admin!');
      }
    }
  }

  foreach my $addressed_command_admin_hook (keys(%{$self->addressed_command_admin_hooks})) {
    my $regexp = $botnick . '(?:,|:|\.|\s)*' . $self->perlbot->config->get(bot => 'commandprefix') . '*' . $addressed_command_admin_hook . '(?:\s+|$)';
    if($text =~ /^${regexp}/i) {
      if($user && $self->perlbot->is_admin($user)) {
        my $texttocallwith = $text;
        $texttocallwith =~ s/${regexp}//i;
        $self->_set_lastcontact($event);
        $self->_dispatch($self->addressed_command_admin_hooks->{$addressed_command_admin_hook}, $user, $texttocallwith, $event);
      }
    }
  }

  # here we just return the event in addition to the other stuff

  foreach my $commandprefix_advanced_hook (keys(%{$self->commandprefix_advanced_hooks})) {
    my $regexp = $self->perlbot->config->get(bot => 'commandprefix') . $commandprefix_advanced_hook;
    if($text =~ /^\Q${regexp}\E(?:\s+|$)/i) {
      my $texttocallwith = $text;
      $texttocallwith =~ s/^\Q${regexp}\E(?:\s+|$)//i;
      $self->_set_lastcontact($event);
      $self->_dispatch($self->commandprefix_advanced_hooks->{$commandprefix_advanced_hook}, $user, $texttocallwith, $event);
    }
  }

  foreach my $addressed_command_advanced_hook (keys(%{$self->addressed_command_advanced_hooks})) {
    my $regexp = $botnick . '(?:,|:|\.|\s)*' . $self->perlbot->config->get(bot => 'commandprefix') . '*' . $addressed_command_advanced_hook . '(?:\s+|$)';
    if($text =~ /^${regexp}/i) {
      my $texttocallwith = $text;
      $texttocallwith =~ s/${regexp}//i;
      $self->_set_lastcontact($event);
      $self->_dispatch($self->addressed_command_advanced_hooks->{$addressed_command_advanced_hook}, $user, $texttocallwith, $event);
    }
  }

  # here we just return raw events

  foreach my $event_hook (@{$self->event_hooks->{$event->type()}}) {
    $self->_set_lastcontact($event);
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
    debug("Forking off plugin: " . $self->name, 3);
    if (!defined($pid = fork)) {
      $self->reply_error("fork error in $self->name plugin");
      return;
    }

    if ($pid) {
      # parent
      $SIG{CHLD} = 'IGNORE'; #sub { wait };
    } else {
      # child
      $coderef->($self, @params);
      $self->perlbot->empty_queue; # send all waiting events
      $self->_shutdown();
      $self->perlbot->shutdown();
    }

  } else {

    $coderef->($self, @params);

  }
}

sub shutdown { } # stub

sub _shutdown {
  my $self = shift;

  
  $self->config->save if $self->config;
  $self->shutdown();
}

sub _set_lastcontact {
  my $self = shift;
  my $event = shift;

  if($event->type() eq 'msg' || $self->behaviors->{reply_via_msg}) {
    $self->lastcontact = $event->nick();
  } else {
    $self->lastcontact = $event->{to}[0];
  }
}

sub _read_help {
  my $self = shift;
  my $filename = shift;
  $filename ||= 'help.xml';

  return read_generic_config(File::Spec->catfile($self->directory, $filename));
}

sub _read_info {
  my $self = shift;
  my $filename = shift;
  $filename ||= 'info.xml';

  return read_generic_config(File::Spec->catfile($self->directory, $filename));
}

1;
