package Perlbot::Plugin::Notes;

use Perlbot;
use Perlbot::User;
use Perlbot::Plugin;

@ISA = qw(Perlbot::Plugin);

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_fork(0);

  $self->hook('note', \&note);
  $self->hook('listnotes', \&listnotes);
  $self->hook('readnote', \&readnote);
}

sub note {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my ($recipient, $note) = split(' ', $text, 2);
  my $sender = $self->{lastcontact};

  if (!$recipient) {
     $self->reply('You must specify a user to leave a note for!');
     return;
  }

  if(exists($self->{perlbot}->{users}->{$recipient})) {
    $self->{perlbot}->{users}->{$recipient}->add_note($sender, $note);
    $self->reply("note added for $recipient");
  } else {
    $self->reply("I don't know the user '$recipient'");
  }
}

sub listnotes {
  my $self = shift;
  my $user = shift;

  if($user) {
    $self->reply($user->listnotes());
  } else {
    $self->reply('You are not a known user!');
  }
}

sub readnote {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  if($user) {
    $self->reply($user->readnote($text));
  } else {
    $self->reply('You are not a known user!');
  }
}

1;
