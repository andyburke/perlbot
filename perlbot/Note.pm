package Note;

use strict;


sub new {
    my $class = shift;
    my $from = shift;
    my ($sec,$min,$hour,$mday,$mon,$year);
    my $date;

    ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    $year += 1900; #yay, y2k!
    $mon += 1;

    $date = sprintf("%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);

    my $self = {
	date => $date,
	from => $from,
	text => shift
	};

    bless $self, $class;
    return $self;
}


1;
