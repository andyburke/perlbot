package Perlbot::Plugin::Help;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_reply_via_msg(1);

  $self->hook('help', \&gethelp);
}

sub gethelp {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my @foundhelp;

  if($text) {
    foreach my $plugin (@{$self->perlbot->{plugins}}) {
      push(@foundhelp, $plugin->_help($text));
    }

    if(!@foundhelp) {
      $self->reply_error("No help found for: $text");
    } else {
      $self->reply(@foundhelp);
    }
  } else {
    $self->reply_error('Please specify a command or plugin name for help!');
    $self->reply_error('Sending the bot the \'listplugins\' command might be a good place to start.');
  }
}

1;
