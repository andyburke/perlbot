package Perlbot::Logs::DBI;

use strict;

use DBI;

use Perlbot::Utils;
use Perlbot::Logs::Event;

use File::Spec;

use base qw(Perlbot::Logs);
use vars qw($AUTOLOAD %FIELDS);
use fields qw(channel dbh dbtype dbname user password);


sub new {
  my ($class, $perlbot, $channel, $dbtype, $dbname, $user, $password) = @_;

  my $self = fields::new($class);

  $self->perlbot = $perlbot;
  $self->channel = $channel;
  $self->dbtype = $dbtype;
  $self->dbname = $dbname;
  $self->user = $user;
  $self->password = $password;

  $self->connect();
  my $tabletest = $self->dbh->prepare("SELECT * FROM logs;");
  if(!$tabletest->execute()) {  # table not yet created

    debug("Creating database table 'logs'");

    my $createtablestring;

    if($dbtype eq 'Pg') {
      debug("Creating a table in PostgreSQL");
      $createtablestring = "

        CREATE TABLE logs (
          eventtime  bigint   NOT NULL,
          eventtype  varchar  NOT NULL,
          nick       varchar  NOT NULL,
          channel    varchar  NOT NULL,
          target     varchar          ,
          userhost   varchar          ,
          text       varchar
        );

      ";
    } # else...

    debug("Create table string: $createtablestring");

    my $query = $self->dbh->prepare($createtablestring);
    $query->execute()
        or die("Could not create table in database!");
    $query->finish();
  }

  $self->disconnect();

  return $self;
}

sub AUTOLOAD : lvalue {
  my $self = shift;
  my $field = $AUTOLOAD;

  $field =~ s/.*:://;

  debug("Got call for field: $field", 15);

  if (!exists($FIELDS{$field})) {
    die "AUTOLOAD: no such method/field '$field'";
  }

  $self->{$field};
}

sub connect {
  my $self = shift;

  my $dbistring = "dbi:" . $self->dbtype . ":dbname=" . $self->dbname;

  $self->dbh = DBI->connect($dbistring, $self->user, $self->password, { RaiseError => 0,
                                                                        PrintError => 0 })
      or die("Could not connect to database for logging!");
}

sub disconnect {
  my $self = shift;

  $self->dbh and
      $self->dbh->disconnect();
}
      
sub log_event {
  my $self = shift;
  my $event = new Perlbot::Logs::Event(shift, $self->channel);
  my $time = $event->time();
  my $type = "'" . $event->as_string_formatted("%type", 'sql') . "'"; $type ne "''" or $type = 'NULL';
  my $nick = "'" . $event->as_string_formatted("%nick", 'sql') . "'"; $nick ne "''" or $nick = 'NULL';
  my $channel = "'" . $event->as_string_formatted("%channel", 'sql') . "'"; $channel ne "''" or $channel = 'NULL';
  my $target = "'" . $event->as_string_formatted("%target", 'sql') . "'"; $target ne "''" or $target = 'NULL';
  my $userhost = "'" . $event->as_string_formatted("%userhost", 'sql') . "'"; $userhost ne "''" or $userhost = 'NULL';
  my $text = "'" . $event->as_string_formatted("%text", 'sql') . "'"; $text ne "''" or $text = 'NULL';

  # why doesn't this work?
  # filter our stuff for SQL compliance
#  no strict 'refs';
#  foreach my $field (qw(type nick channel target userhost text)) {
#    $$field = $event->as_string_formatted("%$field", 'sql');
#    if($$field eq '') { # NULL
#      $$field = 'NULL';
#    } else {
#      $$field = "'" . $$field . "'"; # wrap for the INSERT
#    }
#  }
#  use strict 'refs';

  my $querystring = "
    INSERT INTO logs (eventtime, eventtype, nick, channel, target, userhost, text)
    VALUES($time, $type, $nick, $channel, $target, $userhost, $text);";

  $self->connect();
  my $query = $self->dbh->prepare($querystring);
  if(!$query->execute()) {
    debug("Could not insert event into database!");
  }
  $query->finish();
  $self->disconnect();
}

sub search {
  my $self = shift;
  my $args = shift;

  my $maxresults = $args->{maxresults};
  my $terms = $args->{terms};
  my $nick = $args->{nick}; $nick = undef if (defined($nick) and $nick eq '');
  my $type = $args->{type}; $type = undef if (defined($type) and $type eq '');
  my $initialdate = $args->{initialdate} || 1;
  my $finaldate = $args->{finaldate} || time();
  my $boolean = $args->{boolean} || 0;

  my @result;
  my $resultcount = 0;

  my $querystring = "SELECT * FROM logs WHERE channel = '" . $self->channel . "' AND";
  defined($nick) and $querystring .= " nick = '$nick' AND";
  defined($type) and $querystring .= " eventtype = '$type' AND";
  if(defined($terms)) {
    foreach my $term (@{$terms}) {
      $querystring .= " text LIKE '$term' AND";
    }
  }
  $querystring .= " eventtime >= $initialdate AND eventtime <= $finaldate ORDER BY eventtime;";
  
  $self->connect();
  my $query = $self->dbh->prepare($querystring);
  $query->execute or
      debug("Could not execute query: $querystring");

  while(my ($time, $type, $nick, $channel, $target, $userhost, $text) = $query->fetchrow_array()) {

    if($boolean) {
      $query->finish();
      $self->disconnect();
      return 1;
    }

    $resultcount++;

    if(wantarray()) {

      my $event = new Perlbot::Logs::Event( { time => $time,
                                              type => $type,
                                              nick => $nick,
                                              channel => $channel,
                                              target => $target,
                                              userhost => $userhost,
                                              text => $text } );

      push(@result, $event);
    }
  }

  $query->finish();
  $self->disconnect();
  return wantarray() ? @result : $resultcount;
}

sub initial_entry_time {
  my $self = shift;
  my $querystring = "SELECT MIN(eventtime) FROM logs WHERE channel='" . $self->channel . "';";

  $self->connect();
  my $query = $self->dbh->prepare($querystring);
  if(!$query->execute()) {
    debug("Could not get initial entry time for channel: " . $self->channel);
  }
  my ($time) = $query->fetchrow_array();
  $query->finish();
  $self->disconnect();

  return $time;
}

sub final_entry_time {
  my $self = shift;
  my $querystring = "SELECT MAX(eventtime) FROM logs WHERE channel='" . $self->channel . "';";

  $self->connect();
  my $query = $self->dbh->prepare($querystring);
  if(!$query->execute()) {
    debug("Could not get initial entry time for channel: " . $self->channel);
  }
  my ($time) = $query->fetchrow_array();
  $query->finish();
  $self->disconnect();

  return $time;
}

sub DESTROY {
  my $self = shift;

  $self->disconnect();
}

1;
