package Perlbot::User;

use strict;
use Perlbot::Utils;
use Digest::MD5 qw(md5_base64);

use vars qw($AUTOLOAD %FIELDS);
use fields qw(config name curnick curchans lastnick temphostmasks allowed);

sub new {
    my $class = shift;
    my ($nick, $config) = @_;

    my $self = fields::new($class);

    $self->config = $config;
    $self->name = $nick;
    $self->curnick = $nick;
    $self->curchans = [];
    $self->lastnick = undef;
    $self->temphostmasks = [];
    $self->allowed = {};

    return $self;
}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  if(!exists($FIELDS{$field})) {
    return;
  }

  debug("AUTOLOAD:  Got call for field: $field", 15);

  $self->{$field};
}

sub admin {
  my $self = shift;

  # if the arrayref is undefined, create it
  if (!$self->config->value(bot => 'admin')) {
    $self->config->value('bot', 0)->{admin} = [];
  }
  # insert/remove username from admins hash as requested
  if (@_) {
    my $want_admin = shift(@_);
    if ($want_admin and !$self->admin) {
      push @{$self->config->value(bot => 'admin')}, $self->name;
    } else {
      my $admins = $self->config->value(bot => 'admin');
      @$admins = grep {$_ ne $self->name} @$admins;
    }
  }
  return grep({$_ eq $self->name} @{$self->config->value(bot => 'admin')}) ? 1 : 0;
}

sub is_admin {
  my $self = shift;
  return $self->admin();
}

sub password {
  my $self = shift;
  my $password = shift;

  if(defined($password)) {
    $self->config->value(user => $self->name => 'password') = md5_base64($password);
  }

  return $self->config->value(user => $self->name => 'password');
}

sub authenticate {
  my $self = shift;
  my $data = shift;;

  foreach my $method (qw(password legacy_password)) {
    return 1 if eval "\$self->auth_$method(\$data);";
  }
  return 0;
}

sub auth_password {
  my $self = shift;
  my $password = shift;

  if($self->password() && ($self->password() eq md5_base64($password))) {
    return 1;
  }
  return 0;
}

sub auth_legacy_password {
  my $self = shift;
  my $password = shift;

  if($self->password() && (crypt($password, $self->password()) eq $self->password())) {
    return 1;
  }
  return 0;
}

sub add_hostmask {
  my ($self, $hostmask) = @_;

  validate_hostmask($hostmask) or return;
  push @{$self->hostmasks}, $hostmask;
}


sub add_temp_hostmask {
  my ($self, $hostmask) = @_;

  validate_hostmask($hostmask) or return;
  push @{$self->temphostmasks}, $hostmask;
}

sub del_hostmask {
  my ($self, $hostmask) = @_;

  my $hostmasks = $self->hostmasks;
  @$hostmasks = grep {$_ ne $hostmask} @$hostmasks;
}


sub hostmasks {
  my $self = shift;
  if (!$self->config->value(user => $self->name => 'hostmask')) {
    $self->config->value(user => $self->name)->{hostmask} = [];
  }
  return $self->config->value(user => $self->name => 'hostmask');
}

sub update_channels {
  my $self = shift;
  my $chans = shift;

  $chans =~ s/@//g;

  while(@{$self->{curchans}}) { pop @{$self->{curchans}}; }

  foreach my $chan (split(' ', $chans)) {
    push @{$self->{curchans}}, $chan;
  }
}

1;
