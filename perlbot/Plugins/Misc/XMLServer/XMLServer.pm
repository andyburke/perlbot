package Perlbot::Plugin::XMLServer;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use Perlbot::Utils;
use RPC::XML::Server;
use XML::Simple;

sub init {
  my $self = shift;

  $self->{cfg} = read_generic_config('config');

  my $srv = RPC::XML::Server->new(port => 10000);

  $srv->add_method({ name => 'perlbot.Bot',
                     code => sub { $self->bot() },
                     signature => [ 'string' ] });

  $srv->add_method({ name => 'perlbot.Channel',
                     code => sub { $self->channel() },
                     signature => [ 'string' ] });

  $srv->add_method({ name => 'perlbot.User',
                     code => sub { $self->user() },
                     signature => [ 'string' ] });



  if (!defined($pid = fork)) {
    return;
  }

  if ($pid) {
      # parent
    $SIG{CHLD} = IGNORE; #sub { wait };
  } else {

    $self->{perlbot}{ircconn}{_connected} = 0;

    $srv->server_loop();
  }
  
}

sub bot {
  my $self = shift;

  return XMLout({ bot => $self->{cfg}{bot} });
}

sub channel {
  my $self = shift;

  return XMLout({ channel => $self->{cfg}{channel} });
}

sub user {
  my $self = shift;

  return XMLout({ user => $self->{cfg}{user} });
}

1;




