package WhereDaBitch::Plugin;

# note, this is actually just a partial hack of ender's userinfo plugin

use Perlbot;

sub get_hooks {
    return { msg => \&on_msg, public => \&on_public };
}


sub on_msg {
  my $conn = shift;
  my $event = shift;

  seen($conn, $event, $event->nick);
}



sub on_public {
  my $conn = shift;
  my $event = shift;

  seen($conn, $event, ($event->to)[0]);
}




sub seen {
my $conn = shift;
  my $event = shift;
  my $who = shift;
  my ($nicktext) = ($event->args)[0] =~
      /where(?:\'s|(?:\s+.*?)?\s+is)?\s+(.*?)(?:[?!.]|$)/;
  my @args = split(' ', $nicktext);

  foreach my $user (values(%users)) {
      my $lcnick = lc($user->{nick});
      foreach my $arg (@args) {
	  my $lcarg = lc($arg);
	  if($lcarg eq $lcnick) {
	      if($user->{lastseen} eq 'never') {
		  $conn->privmsg($who, "I haven't seen @args since I got here.");
		  return;
	      } else {
		  my ($sec, $min, $hour, $mday, $mon, $year) =
		      localtime($user->{lastseen});
		  $year += 1900;
		  $mon++;
		  
		  my $time = sprintf("%d/%02d/%02d %02d:%02d:%02d",
				     $year, $mon, $mday, $hour, $min, $sec);
		  
		  $conn->privmsg($who, "I last saw @args at $time");
		  return;
	      }
	  }
      }
  }
}

1;
