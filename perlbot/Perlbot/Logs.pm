package Perlbot::Logs;

use Perlbot;
use Perlbot::Utils;
use strict;

use File::Spec;
use Time::Local;

use vars qw($AUTOLOAD %FIELDS);
use fields qw(perlbot);

sub new {
  my ($class, $perlbot) = @_;

  my $self = fields::new($class);

  $self->perlbot = $perlbot;

  return $self;
}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  if(!exists($FIELDS{$field})) {
    return;
  }

  debug("Got call for field: $field", 15);

  $self->{$field};
}

sub search {
  my $self = shift;

  use Data::Dumper;
  print Dumper (@_);

  my $channel = shift;
  my $termsref = shift; my @terms = @{$termsref};
  my $initialdate = shift;
  my $finaldate = shift;

  my @result;

  $channel = Perlbot::Utils::strip_channel($channel);

  # goddamn, localtime is dumb as fuck

  my ($initialsecond, $initialminute, $initialhour, $initialday, $initialmonth, $initialyear) =
      localtime($initialdate);
  $initialyear += 1900;
  $initialmonth += 1;

  my ($finalsecond, $finalminute, $finalhour, $finalday, $finalmonth, $finalyear) =
      localtime($finaldate);
  $finalyear += 1900;
  $finalmonth += 1;
  
  if(opendir(DIR, File::Spec->catfile($self->perlbot->config->get(bot => 'logdir'), $channel))) {
    my @tmp = readdir(DIR);
    my @files = sort(@tmp);

    foreach my $file (@files) {
      my $initialdate_string = Perlbot::Utils::perlbot_date_filename($initialdate);
      my $finaldate_string = Perlbot::Utils::perlbot_date_filename($finaldate);

      next if $initialdate and $file lt $initialdate_string;
      last if $finaldate and $file gt $finaldate_string;

      open(FILE, File::Spec->catfile($self->perlbot->config->get(bot => 'logdir'), $channel, $file));
      my @lines = <FILE>;
      close FILE;

      $initialdate_string = Perlbot::Utils::perlbot_date_string($initialdate);
      $finaldate_string = Perlbot::Utils::perlbot_date_string($finaldate);
            
      foreach my $line (@lines) {
        next if $initialdate and $line lt $initialdate_string;
        last if $finaldate and $line gt $finaldate_string;
        my $add_to_result = 1;

        foreach my $term (@terms) {
          if($line !~ /$term/i) {
            $add_to_result = 0;
            last;
          }
        }

        push(@result, $line) if $add_to_result;
        
      }
    }
  }

  return @result;
}

1;
