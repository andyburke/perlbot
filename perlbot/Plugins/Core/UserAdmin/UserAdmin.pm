# Andrew Burke <burke@bitflood.org>
#
# This plugin munges the in-memory config and writes it back out,
# careful

package Perlbot::Plugin::UserAdmin;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;

use Perlbot::Utils;
use Perlbot::User;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->want_fork(0);
  $self->want_reply_via_msg(1);
  $self->want_public(0);

  $self->hook_admin('useradmin', \&useradmin);

}

sub useradmin {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($command, $username, $arguments) = split(' ', $text, 3);

  if (!$command) {
    $self->reply('You must specify a command!');
    return;
  }

  if (!$username) {
    $self->reply('You must specify a username!');
    return;
  }

  my $other_user = $self->perlbot->get_user($username);
  if (grep {$_ eq $command} qw(remove hostmasks addhostmask delhostmask password addop)) {
    if (!$other_user) {
      $self->reply("$username is not a known user!");
      return;
    }
  }

  if ($command eq 'add') {
    if ($other_user) {
      $self->reply("User $username already exists!");
      return;
    }
    $self->perlbot->config->value('user')->{$username} = {};
    $self->perlbot->config->save;
    $self->perlbot->users->{$username} = new Perlbot::User($username, $self->perlbot->config);
    $self->reply("Added user: $username");

  } elsif ($command eq 'remove') {
    delete $self->perlbot->users->{$username};
    # hash lookup must be performed "outside" of ->value call for delete to work
    delete $self->perlbot->config->value('user')->{$username};
    $self->perlbot->config->save;
    $self->reply("Removed user: $username");

  } elsif ($command eq 'hostmasks') {
    foreach my $hostmask (@{$other_user->hostmasks}) {
      $self->reply($hostmask);
    }
  } elsif ($command eq 'addhostmask') {
    my $hostmask = $arguments;
    if (!$hostmask) {
      $self->reply('You must specify a hostmask to add!');
      return;
    }
    if (!validate_hostmask($hostmask)) {
      $self->reply("Invalid hostmask: $hostmask");
    } else {
      $other_user->add_hostmask($hostmask);
      $self->perlbot->config->save;
      $self->reply("Permanently added $hostmask to ${username}'s list of hostmasks.");
    }

  } elsif ($command eq 'delhostmask') {
    my $hostmask = $arguments;
    if (!$hostmask) {
      $self->reply('You must specify a hostmask to delete!');
      return;
    }
    my $old_num = @{$other_user->hostmasks};
    $other_user->del_hostmask($hostmask);
    if ($old_num == @{$other_user->hostmasks}) {
      $self->reply("$hostmask is not in ${username}'s list of hostmasks!");
    } else {
      $self->perlbot->config->save;
      $self->reply("Permanently removed $hostmask from ${username}'s list of hostmasks.");
    }

  } elsif ($command eq 'password') {
    my $password = $arguments;
    if (!$password) {
      $self->reply('You must specify a new password!');
      return;
    }
    $other_user->password($password);
    $self->perlbot->config->save;
    $self->reply("Password saved for user: $username");

  } elsif ($command eq 'addop') {
    my $channame = Perlbot::Utils::normalize_channel($arguments);
    if (!$channame || !$username) {
      $self->reply_error('You must specify both a channel and a username!');
      return;
    }
    my $channel = $self->perlbot->get_channel($channame);
    if (!$channel) {
      $self->reply_error("No such channel: $channame");
      return;
    }

    if ($channel->is_op($other_user)) {
      $self->reply("$username is already an op for $channame");
      return;
    }
    
    if($channel->add_op($other_user)) {
      $self->perlbot->config->save;
      $self->reply("Added $username to the list of ops for $channame");
    } else {
      $self->reply("Could not add $username to the list of ops for $channame");
    }

  } elsif ($command eq 'delop') {
    my $channame = Perlbot::Utils::normalize_channel($arguments);
    if (!$channame || !$username) {
      $self->reply_error('You must specify both a channel and a username!');
      return;
    }
    my $channel = $self->perlbot->get_channel($channame);
    if (!$channel) {
      $self->reply_error("No such channel: $channame");
      return;
    }
    if (!$channel->is_op($other_user)) {
      $self->reply("$username is not an op for $channame");
      return;
    }

    if($channel->remove_op($other_user)) {
      $self->perlbot->config->save;
      $self->reply("$username has been removed from the list of ops for $channame");
    } else {
      $self->reply("Could not remove $username from the list of ops for $channame");
    }
  } else {
    $self->reply_error("Unknown command: $command");
    return;

  }

  # successful command
}


1;
