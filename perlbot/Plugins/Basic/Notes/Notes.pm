package Perlbot::Plugin::Notes;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use DB_File;

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_fork(0);

  tie %{$self->{notes}},  'DB_File', File::Spec->catfile($self->{directory}, 'notesdb'), O_CREAT|O_RDWR, 0640, $DB_HASH;
  tie %{$self->{notified}},  'DB_File', File::Spec->catfile($self->{directory}, 'notifieddb'), O_CREAT|O_RDWR, 0640, $DB_HASH;

  $self->hook('note', \&note);
  $self->hook('listnotes', \&listnotes);
  $self->hook('readnote', \&readnote);

  $self->hook_event('public', \&notify);
  $self->hook_event('msg', \&notify);
  $self->hook_event('join', \&notify);
  $self->hook_event('part', \&notify);

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

  foreach my $tmpuser (keys(%{$self->{perlbot}{users}})) {
    if($recipient eq $tmpuser || $recipient eq $self->{perlbot}{users}{$tmpuser}{curnick}) {
      $self->{notes}{$tmpuser} .= time() . ":::${sender}:::${note}::::";
      $self->reply("Note stored for $recipient");
      $self->{notified}{$tmpuser} = 0;
      return;
    }
  }      
  
  $self->reply_error("I don't know the user '$recipient'");

}

sub listnotes {
  my $self = shift;
  my $user = shift;

  if($user) {
    my @notes = split('::::', $self->{notes}{$user->{name}});
    if(!@notes) {
      $self->reply_error('No notes stored for you!');
      return;
    }

    my $notenum = 1;
    foreach my $note (@notes) {
      my ($time, $sender, $notetext) = split(':::', $note);
      $self->reply(" $notenum : [" . localtime($time) . "] from $sender");
      $notenum++;
    }
  } else {
    $self->reply_error('You are not a known user!');
  }
}

sub readnote {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  if($user) {
    my @notes = split('::::', $self->{notes}{$user->{name}});

    if($text) {
      my $notenum = $text;
      my $realnotenum = $text - 1;

      if(!$notes[$realnotenum]) {
        $self->reply_error('No such note!');
        return;
      }

      my ($time, $sender, $notetext) = split(':::', $notes[$realnotenum]);
      $self->reply(" $notenum : [" . localtime($time) . "] from $sender");
      $self->reply("  $notetext");
      splice(@notes, $realnotenum, 1);
      $self->{notes}{$user->{name}} = join('::::', @notes);
      return;
    } else {
      my $note = shift @notes;

      if(!$note) {
        $self->reply_error('You have no notes!');
        return;
      }

      my ($time, $sender, $notetext) = split(':::', $note);
      $self->reply(" 1 : [" . localtime($time) . "] from $sender");
      $self->reply("  $notetext");
      $self->{notes}{$user->{name}} = join('::::', @notes);
      return;
    } 
  } else {
    $self->reply('You are not a known user!');
  }
}

sub notify {
  my $self = shift;
  my $event = shift;
  my $user = $self->{perlbot}->get_user($event->from);

  if($user) {
    if(exists($self->{notified}{$user->name})) {
      if(!$self->{notified}{$user->name}) {
        $self->{perlbot}->msg($user->curnick, 'You have notes stored for you!');
        $self->{notified}{$user->name} = 1;
      }
    }
  }
}

1;



