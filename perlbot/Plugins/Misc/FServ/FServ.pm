# Andrew Burke <burke@bitflood.org>
#

package Perlbot::Plugin::FServ;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;
use File::stat;
use File::Spec;

use Perlbot;
use Net::IRC::DCC;

sub init {
  my $self = shift;
  
  $self->author('Andrew Burke');
  $self->contact('burke@bitflood.org');
  $self->version('1.0.0');
  $self->url('http://perlbot.sourceforge.net');

  opendir(FILEDIR, File::Spec->catfile($self->{directory}, 'files'));
  @{$self->{files}} = grep { $_ !~ /^\.\.*/ } readdir(FILEDIR);
  close FILEDIR;

  # ugly as fuck
  foreach my $filename (@{$self->{files}}) {
    my $stat = stat(File::Spec->catfile($self->{directory}, 'files', $filename));
    push(@{$self->{filesizes}}, sprintf("%.2f", $stat->size / (1024*1024)));
  }

  $self->want_chat(1); # we want dcc chat
  $self->want_reply_via_msg(1);

  $self->hook('fserv', \&fserv);
}

sub fserv {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my ($command, $args) = split(' ', $text);

  if($command eq 'list') {
    $self->reply('Currently offered files:');
    my $filenum = 1;
    foreach my $file (@{$self->{files}}) {
      $self->reply("  $filenum : $file [" . $self->{filesizes}[$filenum - 1] . 'Mb]');
      $filenum++;
    }
    return;
  } elsif($command eq 'send') {
    my $filenum = $args - 1; # real index
    if($self->{files}[$filenum]) {
      $self->reply('Beginning DCC SEND of ' . $self->{files}[$filenum]);
      $self->perlbot->dcc_send($self->{lastnick},
                             File::Spec->catfile($self->{directory}, 'files', $self->{files}[$filenum]));
    } else {
      $self->reply_error('No such file: ' . ++$filenum);
    }
  } elsif($command eq 'open') {
    $self->perlbot->dcc_chat($self->{lastnick}, $self->{lasthost});
  } elsif($command eq '') {
    $self->reply_error('try: list, send');
  } else {
    $self->reply_error("Unknown command: $command");
  }
 
}

1;
