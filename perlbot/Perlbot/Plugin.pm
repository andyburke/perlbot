# Andrew Burke   <burke@bitflood.org>
# Jeremy Muhlich <jmuhlich@bitflood.org>
#
# Plugin base class
#

package Perlbot::Plugin;

use strict;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(name perlbot directory config helpitems infoitems hooks lastcontact lastnick lasthost behaviors);

use Perlbot::Plugin::Hook;

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
  
  $self->hooks = [];

  $self->lastcontact = '';
  $self->lastnick = '';
  $self->lasthost = '';

  return $self;
}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  if(!exists($FIELDS{$field})) {
    die "AUTOLOAD: no such method/field '$field'";
  }

  debug("Got call for field: $field", 15);

  $self->{$field};
}

sub init {
  my $self = shift;

  die(ref($self) . "::init not implemented!");
}

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
  # meant to be overridden, but shouldn't die if they don't
  return undef;
}

sub hook {
  my $self = shift;

  my $trigger;
  my $coderef;
  my $authtype;
  my $eventtypes;
  my $attributes;


  if(@_ > 2) {
    debug("Extraneous arguments!");
    debug(@_);
    die("Extraneous arguments passed to Perlbot::Plugin::hook!");
  }

  if(@_ == 2) {
    $trigger = shift;
    $coderef = shift;
  } else {
    my $args = shift;

    if(ref($args) ne 'HASH') {
      debug("Got something not a hashref!");
      die("Got a piece of shit you suck at coding.");
    }

    $trigger = $args->{trigger};
    $coderef = $args->{coderef};
    $authtype = $args->{authtype};
    $eventtypes = $args->{eventtypes};
    $attributes = $args->{attributes};

  }
      
  my $hook = new Perlbot::Plugin::Hook($trigger, $coderef, $authtype, $eventtypes, $attributes);
  push(@{$self->hooks}, $hook);
}

sub hook_web {
  my $self = shift;
  my $hook = shift;
  my $call = shift;
  my $description = shift;

  $self->perlbot->webserver_add_handler($hook, sub { $self->$call(@_) }, $description, $self->name);
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

sub _handle_event {
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

  $self->_set_lastcontact($event);

  foreach my $hook (@{$self->hooks}) {
    $hook->process($event, $user, $text, $botnick);
  }
}

sub shutdown { } # stub, don't die if they don't do it

sub _shutdown {
  my $self = shift;

  
  $self->config->save if $self->config;
  $self->shutdown();
}

sub _set_lastcontact {
  my $self = shift;
  my $event = shift;

  $self->lastnick = $event->nick;
  $self->lasthost = $event->host;

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

sub DESTROY {
  # dummy
}

1;
