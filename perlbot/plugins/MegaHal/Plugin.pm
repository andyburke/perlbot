package MegaHal::Plugin;

use Perlbot;
use IPC::Open2;

my $proc_pid;

my $lines;
my $trigger_lines = 10;

my $read;
my $write;

my $learn = 0;

my $lastnick;

my @channels;
my $min_users = 10;

sub get_hooks {
  return { endofmotd => \&open_hal, 
	   public => \&on_public,
	   msg => \&on_msg,
	   caction => \&on_action,
	   disconnect => \&close_hal,
           list => \&getchannellist };
}

sub open_hal {
  my $conn = shift;
  my $event = shift;
  
  `echo "#!/bin/sh" > $plugindir/MegaHal/run-hal`;
  `echo "cd $plugindir/MegaHal" >> $plugindir/MegaHal/run-hal`;
  `echo "./megahal" >> $plugindir/MegaHal/run-hal`;
  `chmod u+x $plugindir/MegaHal/run-hal`;
  `chmod u+x $plugindir/MegaHal/megahal`;

  $proc_pid = open2( \*read, \*write, "$plugindir/MegaHal/run-hal");
  my $he_said = <read>;
  
  $read = \*read;
  $write = \*write;

}

sub on_public {
  my $conn = shift;
  my $event = shift;

  my $who = $event->{to}[0];
  $lines++;

  hal($conn, $event, $who, 0);
}

sub on_msg {
  my $conn = shift;
  my $event = shift;

  my $who = $event->nick;

  if($event->{args}[0] =~ /^${pluginchar}quithal/) {
    if($write) {
      print $write "#quit\n\n";
      $conn->privmsg($who, "Hal should have quit...");
      if($read) { close $read; }
      close $write;
    } else {
      $conn->privmsg($who, "Hal not running?");
    }
  }
  if($event->{args}[0] =~ /^${pluginchar}starthal/) {
    if($write || $read) {
      print $write "#quit\n\n";
      $conn->privmsg($who, "Hal was running or something?");
      if($read) { close $read; }
      close $write;
    }
    open_hal($conn, $event);
  }
  if($event->{args}[0] =~ /^${pluginchar}save/) {
    if($write) {
      print $write "#save\n\n";
      $conn->privmsg($who, "Hal's brain should have been saved...");
    }
  }
  if($event->{args}[0] =~ /^${pluginchar}trigger/) {
    ($trigger_lines) = ($event->{args}[0] =~ /^${pluginchar}trigger\s+(\d+)/);
    $conn->privmsg($who, "Hal's trigger lines now: $trigger_lines");
  }
  if($event->{args}[0] =~ /^${pluginchar}learn/) {
    if($learn == 1) { 
      $learn = 0;
      $conn->privmsg($who, "learning off (responses)");
    } else {
      $learn = 1;
      $conn->privmsg($who, "learning on (no responses)");
    }
  }
  if($event->{args}[0] =~ /^${pluginchar}minusers/) {
    ($min_users) = ($event->{args}[0] =~ /^\${pluginchar}minusers\s+(\d+)/);
    $conn->privmsg($who, "Min Users now: " . $min_users);
  }
  if($event->{args}[0] =~ /^${pluginchar}status/) {
    $conn->privmsg($who, "Channels in channels array: " . @channels);
    $conn->privmsg($who, "Min Users to get added to chan array: " . $min_users);
    $conn->privmsg($who, "Trigger lines: " . $trigger_lines);
    $conn->privmsg($who, "Learning: " . $learn);
  }
  if($event->{args}[0] =~ /^${pluginchar}getchanlist/) {
    $conn->privmsg($who, "Getting channel list, this could take a while...");
    while(@channels) {
      pop @channels;
    }
    $conn->list();
  }
  if($event->{args}[0] =~ /^${pluginchar}dumpchanlist/) {
    $conn->privmsg($who, "Dumping channel list...");
    while(@channels) {
      pop @channels;
    }
  }
  if($event->{args}[0] =~ /^${pluginchar}orderchans/) {
    my @newchannels = sort { $b->[1] <=> $a->[1] } @channels;
    my $i = 0;
    while($newchannels[$i]) {
      $channels[$i] = $newchannels[$i];
      $i++;
    }
    $conn->privmsg($who, "Channels should be in order now...");
  }
  if($event->{args}[0] =~ /^${pluginchar}jointopchan/) {
    if(@channels) {
      my $chan = @{shift @channels}->[0];
      $channels{to_channel($chan)} = new Chan(to_channel($chan));
      $channels{to_channel($chan)}->join($conn);
      $conn->privmsg('#fdn', "Joining $chan at the behest of $who");
      $conn->privmsg('#perlbot', "Joining $chan at the behest of $who");
    } else {
      $conn->privmsg($who, "No channels...");
    }
  } 
  if($event->{args}[0] !~ /^($commandchar|$pluginchar)/) {
    hal($conn, $event, $who, 1);
  }
}  

sub on_action {
  my $conn = shift;
  my $event = shift;

  my $who = $event->{to}[0];
  $lines++;

  my $text = join(' ', @{$event->{args}});

  $event->{args}[0] = $text;
 
  hal($conn, $event, $who, 0);
}

sub getchannellist {
  my $conn = shift;
  my $event = shift;

  if($event->{args}[2] > $min_users) {
    push @channels, [$event->{args}[1], $event->{args}[2]];
  }
}

sub hal {
  my $conn = shift;
  my $event = shift;
  my $who = shift;
  my $should_reply = shift or $should_reply = 0;
  my $text = $event->{args}[0];
  my $from = '';
  my $reply;
  my $botnick = substr($conn->nick(), 0, 4); #hackish

  if($text =~ /$botnick/i) { 
    $should_reply = 1;
    $from = $event->nick;
  }

  $text =~ s/^.*?(?:\:+|\-+)\s*//;
  $text =~ s/^\w*\,+\s*//;
  $text =~ s/<$botnick.*?>\s*//ig;
  $text =~ s/$botnick.*?\s+//ig;
  $text =~ s/$botnick.*?$//ig; #this pisses me off...
  $text =~ s/\#//g;

  if($write) { print $write "$text\n\n"; }

  if($read) { $reply = <$read>; }
  chomp $reply;
  my $reply_wait = sprintf("%.0d", length($reply) / 7);

  if($lines > $trigger_lines) {
    if((rand() * 10) % 2 == 0) {
      $should_reply = 1;
      $lines = 0;
    }
  }

  if($should_reply && !$learn) {
    if($reply =~ /^(?:he\s+|she\s+|it\s+|.*?s\s+|.*?n\'t\s+)/i) {
      my ($temptest) = $reply =~ /^(he\s+|she\s+|it\s+|.*?s\s+|.*?n\'t\s+)/i;
      if((split(' ', $temptest) == 1) && ((rand() * 10) % 2 == 0)) {
	$reply =~ s/^(?:he\s+|she\s+|it\s+)//i;
	$reply =~ s/^.*?\'s/\'s/;
	$reply =~ tr/[A-Z]/[a-z]/;
	if($reply_wait) { 
	  sleep($reply_wait);
	  $conn->me($who, $reply);
	  return;
	} else {
	  $conn->me($who, $reply);
	  return;
	}
      }
    }

    if(($from ne '') && !((rand() * 10) % 5 == 0)) {
	if($reply_wait) {
	    sleep($reply_wait);
	    $conn->privmsg($who, "$from: $reply");
	    return;
	} else {
	    $conn->privmsg($who, "$from: $reply");
	    return;
	}
    }

    
    if($reply_wait) {
      if((rand() * 10) % 5 == 0) {
	$reply = $lastnick . ':' . $reply;
      }
      sleep($reply_wait);
      $conn->privmsg($who, $reply);

      return;
    } else {
      if((rand() * 10) % 5 == 0) {
	$reply = $lastnick . ':' . $reply;
      }
      $conn->privmsg($who, $reply);
      return;
    }
  }
  $lastnick = $event->nick;
}

sub close_hal {
  if($write) { print $write "#quit\n\n"; }
  `kill $proc_pid`;
  `kill -9 $proc_pid`;
}


1;
