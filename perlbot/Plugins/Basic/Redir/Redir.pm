package Perlbot::Plugin::Redir;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot;
use Perlbot::Utils;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->{redirs} = {};

  $self->want_fork(0);

  $self->hook_admin('redir', \&adminredirs);
  $self->hook_event('public', \&redir);
}

sub adminredirs {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($command, $source, $dest) = split(' ', $text, 3);

  if(lc($command) eq 'add') {    
    if(!defined($source) || !defined($dest)) {
      $self->reply_error("You must specify a source and a destination channel!");
      return;
    }
    push(@{$self->{redirs}{normalize_channel($source)}}, normalize_channel($dest));
    $self->reply("Added a redirect from $source to $dest");
    return;
  } elsif(lc($command) eq 'del') {
    if(!defined($source) || !defined($dest)) {
      $self->reply_error("You must specify a source and a destination channel!");
      return;
    }
    if($self->{redirs}{normalize_channel($source)}) {
      @{$self->{redirs}{normalize_channel($source)}} =
            grep { $_ ne $dest } @{$self->{redirs}{normalize_channel($source)}};
        $self->reply("Removed redirect from $source to $dest");
        return;
    } else {
      $self->reply("No such redirect: $source -> $dest");
      return;
    }
  } elsif(lc($command) eq 'list') {
    if(keys(%{$self->{redirs}}) == 0) {
      $self->reply_error("No current channel redirections!");
      return;
    }
    foreach my $src (keys(%{$self->{redirs}})) {
      $self->reply("$src -> " . $self->{redirs}{$src});
    }
    return;
  }
}

sub redir {
  my $self = shift;
  my $event = shift;

  my $chan = $event->{to}[0];

  if($self->{redirs}{normalize_channel($chan)}) {
    foreach my $target (@{$self->{redirs}{normalize_channel($chan)}}) {
      $self->perlbot->msg($target, "[${chan}] <$event->{nick}> $event->{args}[0]");
    }
  }
}

1;
