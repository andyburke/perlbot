package Perlbot::Plugin::Hook;

use strict;
use vars qw($AUTOLOAD %FIELDS);
use fields qw(trigger code authtype eventtypes attributes);

sub new {
  my $class = shift;
  my $trigger = shift;
  my $coderef = shift;
  my $authtype = shift;
  my $eventtypes = shift;
  my $attributes = shift;

  my $self = fields new($class);

  $self->trigger = $value;
  $self->coderef = $coderef;
  $self->authtype = $authtype;
  $self->eventtypes = $eventtypes || ['public', 'msg'];
  $self->attributes = $attributes || { respond_when_addressed => 1 };
                                       
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

sub process {
  my $self = shift;
  my $event = shift;
  my $user = shift;
  my $text = shift;
  my $botnick = shift;

  if(!ref($self->trigger)) {

    # return if we ignore this type of event
    grep(/$event->type/, @{$self->eventtypes}) or return;

    #if it's just a command...
    if($self->trigger =~ /\w+/) {

      my $regexp = $self->perlbot->config->get(bot => 'commandprefix') . $self->trigger;
      if($text =~ /^\Q${regexp}\E(?:\s+|$)/i) {
        $self->coderef->($self, $user, $text, $event);
      }

    } else { #if it's a regexp

      if($text =~ /$self->trigger/) {
        $self->coderef->($self, $user, $text, $event);
      }

    }

  } elsif(ref($self->trigger) eq 'CODE') {

    #if $self->trigger returns true...
    if($self->trigger->($self, $user, $text, $event)) {
      $self->coderef->($self, $user, $text, $event);
    }

  }
  
}

1;
