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

sub password {
  my $self = shift;
  my $password = shift;

  if (defined($password)) {
    $self->config->set(user => $self->name => 'password', md5_base64($password));
  }

  return $self->config->get(user => $self->name => 'password');
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
  $self->config->array_push(user => $self->name => 'hostmask', $hostmask);
}

sub add_temp_hostmask {
  my ($self, $hostmask) = @_;

  validate_hostmask($hostmask) or return;
  push @{$self->temphostmasks}, $hostmask;
}

sub remove_hostmask {
  my ($self, $hostmask) = @_;

  $self->config->array_delete(user => $self->name => 'hostmask', $hostmask);
}


sub hostmasks {
  my $self = shift;

  return $self->config->array_get(user => $self->name => 'hostmask');
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
