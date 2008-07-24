package Perlbot::Logs::DBI;

use strict;

use DBI;

use Perlbot::Utils;
use Perlbot::Logs::Event;

use File::Spec;

use base qw(Perlbot::Logs);
use vars qw($AUTOLOAD %FIELDS);
use fields qw(dbh insertquery);


sub new {
  my ($class, $perlbot, $channel, $config, $index) = @_;

  my $self = fields::new($class);

  $self->perlbot = $perlbot;
  $self->channel = $channel;
  $self->config = $config;
  $self->index = $index;

  my $dbistring = "dbi:"
                  . $self->config_get('dbtype')
                  . ":dbname=" . $self->config_get('dbname');

  $dbistring .= ';host=' . $self->config_get('dbhost') if($self->config_get('dbhost'));
  $dbistring .= ';port=' . $self->config_get('dbhost') if($self->config_get('dbport'));

  $self->dbh = DBI->connect($dbistring,
                            $self->config_get('dbuser'),
                            $self->config_get('dbpassword'),
                            { RaiseError => 1,
                              PrintError => 1,
                              InactiveDestroy => 1})
      or die("Could not connect to database for logging!");
  

  my $tabletest = $self->dbh->prepare("SELECT * FROM logs;");
  if(!$tabletest->execute()) {  # table not yet created

    debug("Creating database table 'logs'");

    my $createtablestring;

    if($self->config_get('dbtype') eq 'Pg') {
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
        )

      ";
    } elsif($self->config_get('dbtype') eq 'mysql') {
      debug("Creating a table in MySQL");
      $createtablestring = q{

        CREATE TABLE logs (
          eventtime bigint(20)   NOT NULL,
          eventtype varchar(100) NOT NULL,
          nick      varchar(100) NOT NULL,
          channel   varchar(100) NOT NULL,
          target    varchar(100)         ,
          userhost  varchar(100)         ,
          text      text
        )

      };
    } # else...

    debug("Auto-creating logs table!");
    debug("Create table string: $createtablestring", 2);

    my $query = $self->dbh->prepare($createtablestring);
    $query->execute()
        or die("Could not auto-create logs table in database!");
    $query->finish();
  }

  $self->insertquery =
      $self->dbh->prepare(q{INSERT INTO
                                logs (eventtime, eventtype, nick, channel, target, userhost, text)
                                VALUES (?, ?, ?, ? ,? , ?, ?)});
  
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

sub disconnect {
  my $self = shift;

  if(defined($self->dbh)) {
    $self->dbh->disconnect() or
        debug("Could not disconnect from database: " . $self->dbh->errstr());
  } else {
    debug("No database handle defined!");
  }
}
      
sub log_event {
  my $self = shift;
  my $event = shift;

  $self->insertquery->execute($event->time,
                              $event->type,
                              $event->nick,
                              $event->channel,
                              $event->target,
                              $event->userhost,
                              $event->text)
      or debug("Could not insert event into database: " . $self->dbh->errstr());

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
  if(defined($terms) && @{$terms}) {
    foreach my $term (@{$terms}) {
      $querystring .= " text LIKE '$term' AND";
    }
  }
  $querystring .= " eventtime >= $initialdate AND eventtime <= $finaldate ORDER BY eventtime";
  
  my $query = $self->dbh->prepare($querystring);
  $query->execute or
      debug("Could not execute query: $querystring");

  while(my ($time, $type, $nick, $channel, $target, $userhost, $text) = $query->fetchrow_array()) {

    if($boolean) {
      $query->finish();
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
  return wantarray() ? @result : $resultcount;
}

sub initial_entry_time {
  my $self = shift;
  my $querystring = "SELECT MIN(eventtime) FROM logs WHERE channel='" . $self->channel."'";

  my $query = $self->dbh->prepare($querystring);
  if(!$query->execute()) {
    debug("Could not get initial entry time for channel: " . $self->channel);
  }
  my ($time) = $query->fetchrow_array();
  $query->finish();

  return $time;
}

sub final_entry_time {
  my $self = shift;
  my $querystring = "SELECT MAX(eventtime) FROM logs WHERE channel='" . $self->channel."'";

  my $query = $self->dbh->prepare($querystring);
  if(!$query->execute()) {
    debug("Could not get initial entry time for channel: " . $self->channel);
  }
  my ($time) = $query->fetchrow_array();
  $query->finish();

  return $time;
}

sub DESTROY {
  my $self = shift;

  if($$ == $self->perlbot->masterpid) { # make sure we're the parent
    $self->disconnect();
  }
}

1;
