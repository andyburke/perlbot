package Perlbot::Logs;

use Perlbot::Utils;
use strict;

use File::Spec;

# note: This used to be called 'Log' instead of 'Logs', but when we put
# perlbot into CVS, Log created problems with keyword substitution.
# So it's called Logs now.

sub new {
    my ($class, $logdir, $chan) = @_;
    my ($mday,$mon,$year);

    (undef,undef,undef,$mday,$mon,$year) = localtime;
    $year += 1900; #yay, y2k!
    $mon += 1;

    my $self = {
        logdir => $logdir,
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

    if($DEBUG) {
      print "Updating date to: $year.$mon.$mday\n";
    }

    $self->curyr($year);
    $self->curmon($mon);
    $self->curday($mday);
}

sub open {
    my $self = shift; 
    my $date;

    # make necessary dirs if they don't exist
    stat $self->{logdir} or mkdir($self->{logdir}, 0755);
    stat File::Spec->catfile($self->{logdir}, strip_channel($self->chan)) or mkdir(File::Spec->catfile($self->{logdir}, strip_channel($self->chan)), 0755);

    $self->update_date();
    $date = sprintf("%04d.%02d.%02d", $self->curyr, $self->curmon, $self->curday);

    if($DEBUG) {
      print "Opening log file: " . $self->curyr . "." . $self->curmon . "." . $self->curday . "\n";
    }


    $self->{file}->close if $self->{file}->opened;   # is this necessary?
    my $result = $self->{file}->open(">>" . File::Spec->catfile($self->{logdir}, strip_channel($self->chan), "$date"));
    if (!$result) {
      print "Could not open logfile " . File::Spec->catfile($self->{logdir}, strip_channel($self->chan), "$date") . ": $!\n" if $DEBUG;
    }
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

    ($sec,$min,$hour,$mday,$mon,$year) = localtime;
    $year += 1900;
    $mon += 1;
    
    if(!$self->{file}->opened) { $self->open(); } 

    # if the date has changed, roll the log file
    unless ($mday==$self->curday and $mon==$self->curmon and $year==$self->curyr) {
	print "Rolling log file\n" if $DEBUG;
	$self->open();
    }

    $date = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    $logentry =~ s/\n//g;
    $self->{file}->print("$date " . $logentry . "\n");
    $self->{file}->flush();
}


1;


