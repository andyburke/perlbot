package Perlbot::Plugin::Hook;

use strict;
use vars qw($AUTOLOAD %FIELDS);
use fields qw(trigger coderef authtype eventtypes attributes);

use Perlbot::Utils;

sub new {
  my $class = shift;
  my $trigger = shift;
  my $coderef = shift;
  my $authtype = shift;
  my $eventtypes = shift;
  my $attributes = shift;

  my $self = fields::new($class);

  $eventtypes = [ $eventtypes ] if defined $eventtypes && ref($eventtypes) ne 'ARRAY';

  $self->trigger = $trigger;
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
  my $plugin = shift;
  my $event = shift;
  my $user = shift;
  my $text = shift;
  my $botnick = shift;

  if ( $user && $self->authtype && !$plugin->perlbot->is_admin($user) )
  {
    $plugin->perlbot->msg($event->nick(), 'You are not an admin!');
    return;
  }

  if( ref($self->trigger) eq "CODE" )
  {
     #if $self->trigger returns true...
    if($self->trigger->($plugin, $user, $text, $event)) {
      $self->coderef->($plugin, $user, $text, $event);
    }
  }
  else {
    # return if we ignore this type of event
    my $type = $event->type;
    return if !grep {$type eq $_} @{$self->eventtypes};

    #if it's just a command...
    if(!defined $self->trigger)
    {
        $self->coderef->($plugin, $user, $text, $event);
    }
    elsif ($self->trigger =~ /\w+/) {

      my $regexp = $plugin->perlbot->config->get(bot => 'commandprefix') . $self->trigger;
      if($text =~ /^\Q${regexp}\E(?:\s+|$)/i) {
        $self->coderef->($plugin, $user, $text, $event);
      }

    } else { #if it's a regexp

      if($text =~ /$self->trigger/) {
        $self->coderef->($plugin, $user, $text, $event);
      }

    }

  }  

}

1;
