package Perlbot::Plugin::Authentication;

use Plugin;
@ISA = qw(Plugin);

use strict;

use Perlbot;
use Perlbot::Utils;

sub init {
  my $self = shift;

  $self->want_public(0);
  $self->want_fork(0);

  $self->advanced_hook('auth', \&auth);
  $self->hook('password', \&password);
  $self->hook('hostmasks', \&hostmasks);
  $self->hook('addhostmask', \&addhostmask);
  $self->hook('delhostmask', \&delhostmask);
}

sub auth {
    my $self = shift;
    my $user = shift;
    my $event = shift;
    my $userhost = $event->nick.'!'.$event->userhost;
    my ($username, $password) = split(' ', shift, 2);
    
    if(!$username || !$password || $password eq "''") {
	#FIXME: make this return the help shit
	$self->reply('usage: auth <username> <password>');
	return;
    }
    
    if($self->{perlbot}{users}{$username}) {
	if($self->{perlbot}{users}{$username}->password()
	   && (crypt($password, $self->{perlbot}{users}{$username}->password()) eq $self->{perlbot}{users}{$username}->password())) {
	    $self->{perlbot}{users}{$username}->hostmasks($userhost); # add this hostmask
	    $self->reply("User $username authenticated!");
	} else {
	    $self->reply('Bad password!');
	}
    } else {
	$self->reply("No such user: $username");
	return;
    }
}

sub password {
  my $self = shift;
  my $user = shift;
  my $newpassword = shift;

  if(!$newpassword) {
    $self->reply('Must specify a new password!');
    return;
  }

  if(!$user) {
    $self->reply('Not a known user, try auth first!');
    return;
  }

  $newpassword =  crypt($newpassword, join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64]);
  $self->{perlbot}{config}{user}{$user->{name}}{password} = $newpassword;
  $self->{perlbot}->write_config();
  $user->password($newpassword);

  $self->reply('Password successfully changed');
}

sub hostmasks {
  my $self = shift;
  my $user = shift;

  if(!$user) {
    $self->reply('Not a known user, try auth first!');
    return;
  }

  my $tmpconfig = $self->{perlbot}->read_config();

  foreach my $hostmask (@{$tmpconfig->{'user'}->{$user->name}->{'hostmask'}}) {
    $self->reply($hostmask);
  }
     
}

sub addhostmask {
  my $self = shift;
  my $user = shift;
  my $hostmask = shift;
  
  if(!$hostmask) {
    $self->reply('You must specify a hostmask to add!');
    return;
  }
  
  if(!$user) {
    $self->reply('You are not a known user!');
    return;
  }

  if(!validate_hostmask($hostmask)) {
    $self->reply("Invalid hostmask: $hostmask");
  } elsif(!$self->{perlbot}{config}{user}{$user->{name}}) {
    $self->reply("Your user object doesn't exist, that is bad... contact your bot admin");
  } else {
    push(@{$self->{perlbot}{config}{user}{$user->{name}}{hostmask}}, $hostmask);
    $self->{perlbot}->write_config();
    $user->hostmasks($hostmask);
    $self->reply("Permanently added $hostmask to your list of hostmasks.");
  }

}

sub delhostmask {
  my $self = shift;
  my $user = shift;
  my $hostmask = shift;

  if(!$hostmask) {
    $self->reply('You must specify a hostmask to delete!');
    return;
  }

  if(!$user) {
    $self->reply('You are not a known user!');
    return;
  }

  my $whichhost = 0;
  foreach my $confighostmask (@{$self->{perlbot}{config}{user}{$user->{name}}{hostmask}}) {
    if($confighostmask eq $hostmask) {
      last;
    }
    $whichhost++;
  }

  if($whichhost > @{$self->{perlbot}{config}{user}{$user->{name}}{hostmask}}) {
    $self->reply("$hostmask not in your list of hostmasks!");
    return;
  }

  splice(@{$self->{perlbot}{config}{user}{$user->{name}}{hostmask}}, $whichhost, 1);
  $self->{perlbot}->write_config();
  $self->reply("Permanently removed $hostmask from your list of hostmasks.");

}

1;









