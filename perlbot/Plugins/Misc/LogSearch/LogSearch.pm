package Perlbot::Plugin::LogSearch;

use strict;

use Perlbot::Plugin;
use base qw(Perlbot::Plugin);

use Perlbot::Utils;
use Perlbot::Logs;

use Time::Local;
use Date::Manip;

sub init {
  my $self = shift;

  $self->hook('logsearch', \&logsearch);
}

sub logsearch {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my ($channel) = $text =~ /channel=(.*?)(\s+\w+=|$)/i;
  my (undef, $maxresults) = $text =~ /(maxresults|limit)=(.*?)(\s+\w+=|$)/i;
  my (undef, $initialdate) = $text =~ /(initialdate|startdate|start|starting|beginning|begin)=(.*?)(\s+\w+=|$)/i;
  my (undef, $finaldate) = $text =~ /(finaldate|enddate|finish|ending|end)=(.*?)(\s+\w+=|$)/i;
  my (undef, $termstring) = $text =~ /(words|terms)=(.*?)(\s+\w+=|$)/i;

  if(!$channel) {
    $self->reply_error('You must specify a channel!');
    return;
  }

  my $channel_obj = $self->perlbot->get_channel($channel);

  if(!$channel_obj) {
    $self->reply_error("No such channel: $channel");
    return;
  }

  if(defined($maxresults) && $maxresults > 10) {
    $self->Reply_error('A maximum of 10 results are allowed!');
    return;
  }

  if(!$termstring) {
    $self->reply_error('You must specify terms to search for!');
    return;
  }

  my @terms = split(/ /, $termstring);

  my $args = {};
  $args->{terms} = \@terms;
  $args->{maxresults} = $maxresults || 5;
  $args->{initialdate} = Date::Manip::UnixDate($initialdate,'%s') if defined($initialdate);
  $args->{finaldate} = Date::Manip::UnixDate($finaldate,'%s') if defined($finaldate);

  my @results = $channel_obj->logs->search($args);

  if(@results) {
    foreach my $result (@results) {
      $self->reply($result->as_string());
    }
  } else {
    $self->reply_error('No results found!');
  }

}

1;
