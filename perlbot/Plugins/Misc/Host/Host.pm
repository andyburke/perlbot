# Host plugin
# Andrew Burke burke@bitflood.org

package Perlbot::Plugin::Host;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);

use Perlbot::Utils;
use Net::DNS;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  $self->hook('host', \&host);
  $self->hook('nslookup', \&host);
}

sub host {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  if(!$text) {
    $self->reply('You must specify a hostname to look up!');
  } else {

#    my @result = Perlbot::Utils::exec_command('host', $text);

#    foreach my $line (@result) {
#      $self->reply($line);
#    }

    my $resolver = new Net::DNS::Resolver;
    my $query = $resolver->search($text);

    if($query) {
      my @results = $query->answer();
      my $ip;
      my $realname;

      foreach my $result (@results) {
        if($result->type() eq 'CNAME') {
          $realname = $result->cname();
        }
        if($result->type() eq 'A') {
          $ip = $result->address();
        }
      }

      $self->reply($text . " has address $ip ($realname)");
    } else {
      $self->reply_error("$text not found!");
    }

  }
}



