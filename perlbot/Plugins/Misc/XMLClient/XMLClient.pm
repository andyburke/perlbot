package Perlbot::Plugin::XMLClient;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;
use RPC::XML::Client;
use XML::Simple;

sub init {
  my $self = shift;

  $self->author('Andrew Burke');
  $self->contact('burke@bitflood.org');
  $self->version('1.0.0');
  $self->url('http://perlbot.sourceforge.net');

  my $cli = RPC::XML::Client->new('http://' .
                                $self->config->value(master => 'host') .
                                ':' .
                                $self->config->value(master => 'port'));

  my $xml = XMLin($cli->send_request(RPC::XML::request->new('perlbot.User'))->value->value());
  my ($field) = keys(%{$xml});

#  $self->perlbot->config->value('user') = XMLin($users->value->value());
  $self->perlbot->config->{_config}{$field} = ${$xml}{$field};

  $self->perlbot->process_config();

}

1;
