package Protection::Plugin;

my $last_mode_change_time;
my %last_mode_changer;

sub get_hooks {
    return { mode => \&modechange };
}

sub modechange {
    my $conn = shift;
    my $event = shift;
    my $current_mode_change_time;
    my $mintime = 10;
    my $maxdeops = 2;
    my $timedif = 0;
    
    my $deop_ratio = $maxdeops / $mintime;
    
    my $curnick = (split('!', $event->{from}))[0];
    
    my $curchan = $event->{to}[0];
    
    my $curmode = $event->{args}[0];
    my $curtarget = $event->{args}[1];
    
    my $deops = length(($curmode =~ /-(o+)/g)[0]);

    if(!$deops) { # they didn't deop anyone, we can ignore
      return;
    }

    $current_mode_change_time = time();
    
    if(!$last_mode_change_time || !%last_mode_changer) {
	$last_mode_change_time = $current_mode_change_time;
	
	$last_mode_changer{'nick'} = $curnick;
	$last_mode_changer{'chan'} = $curchan;
	$last_mode_changer{'mode'} = $curmode;
	$last_mode_changer{'target'} = $curtarget;
        $last_mode_changer{'deops'} = $deops;
    }
    
    $timedif = $current_mode_change_time - $last_mode_change_time;
    if($timedif < 1) { $timedif = 1; }
    
    if($last_mode_changer{'nick'} eq $curnick) {
	if(($deops / $timedif) > $deop_ratio) {
	    $conn->mode($curchan, "-o", $curnick);
	}
    }

    $last_mode_change_time = $current_mode_change_time;
    
    $last_mode_changer{'nick'} = $curnick;
    $last_mode_changer{'chan'} = $curchan;
    $last_mode_changer{'mode'} = $curmode;
    $last_mode_changer{'target'} = $curtarget;
    if($last_mode_changer{'nick'} eq $curnick) {
	$last_mode_changer{'deops'} += $deops;
    } else {
	$last_mode_changer{'deops'} = 0;
    }
}

1;



