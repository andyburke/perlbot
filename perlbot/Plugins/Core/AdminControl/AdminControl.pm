package Perlbot::Plugin::AdminControl;

use Perlbot;
use Perlbot::Utils;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_fork(0);

  $self->hook_admin('reload', \&reload);
  $self->hook_admin('debug', \&debugchange);
}

sub reload {
  my $self = shift;
  my $user = shift;

  if($self->perlbot->reload_config()) {
    $self->reply('Reloaded config file!');
  } else {
    $self->reply_error('Could not reload config file!');
  }
}

sub debugchange {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($newdebuglevel) = $text =~ /(\d+)/;

  if(defined($newdebuglevel)) {
    debug("Setting new debug level to $newdebuglevel via irc!!", 0);
    set_debug($newdebuglevel);
  }

  $self->reply('Debugging level set to: ' . set_debug());
}

1;
