package Logs;

use Perlbot;
use strict;
# basedir is a global used to store the location of the channel logs
use vars qw($basedir);

# note: This used to be called 'Log' instead of 'Logs', but when we put
# perlbot into CVS, Log created problems with keyword substitution.
# So it's called Logs now.

sub new {
    my ($class, $chan) = @_;
    my ($mday,$mon,$year);

    (undef,undef,undef,$mday,$mon,$year) = localtime;
    $year += 1900; #yay, y2k!
    $mon += 1;

    my $self = {
	chan   => $chan,
	curyr  => $year,
	curmon => $mon,
	curday => $mday,
	file   => new IO::File
	};

    bless $self, $class;
    return $self;
}

sub chan {
    my $self = shift;
    $self->{chan} = shift if @_;
    return $self->{chan};
}

sub curyr {
    my $self = shift;
    $self->{curyr} = shift if @_;
    return $self->{curyr};
}

sub curmon {
    my $self = shift;
    $self->{curmon} = shift if @_;
    return $self->{curmon};
}

sub curday {
    my $self = shift;
    $self->{curday} = shift if @_;
    return $self->{curday};
}

sub update_date {
    my $self = shift;
    my ($mday,$mon,$year);

    (undef,undef,undef,$mday,$mon,$year) = localtime;
    $year += 1900; #yay, y2k!
    $mon += 1;

    $self->curyr($year);
    $self->curmon($mon);
    $self->curday($mday);
}

sub open {
    my $self = shift; 
    my $date;

    use Data::Dumper;

    # make necessary dirs if they don't exist
    stat $basedir or mkdir($basedir, 0755);
    stat $basedir.$dirsep.from_channel($self->chan) or mkdir($basedir.$dirsep.from_channel($self->chan), 0755);
    print $basedir.$dirsep.from_channel($self->chan) . "\n";

    print Dumper($self) . "\n";

    $date = sprintf("%04d.%02d.%02d", $self->curyr, $self->curmon, $self->curday);

    $self->update_date();
    $self->{file}->close if $self->{file}->opened;   # is this necessary?
    $self->{file}->open(">>$basedir".$dirsep.from_channel($self->chan).$dirsep."$date");
    print ">>$basedir".$dirsep.from_channel($self->chan).$dirsep."$date" . "\n";
}

sub close {
    my $self = shift;
    $self->{file}->close;
}

sub write {
    my $self = shift;
    my $logentry = shift;
    my ($sec,$min,$hour,$mday,$mon,$year);
    my $date;

    print "Writing to log for channel: " . $self->chan . "\n";

    ($sec,$min,$hour,$mday,$mon,$year) = localtime;
    $year += 1900;
    $mon += 1;
    
    # make sure the log file's there...
    #    stat ">>basedir".$dirsep.from_channel($self->chan).$dirsep.$self->curyr.'.'.$self->curmon.'.'.$self->curday or
    if(!$self->{file}->opened) { $self->open(); } 

    # if the date has changed, roll the log file
    unless ($mday==$self->curday and $mon==$self->curmon and $year==$self->curyr) {
	print "Rolling log file\n" if $debug;
	$self->open();
    }

    $date = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    $logentry =~ s/\n//g;
    $self->{file}->print("$date " . $logentry . "\n");
    $self->{file}->flush();
}


1;


