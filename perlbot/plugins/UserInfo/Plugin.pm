package UserInfo::Plugin;

use Perlbot;

my $version = '0.1.0';

sub get_hooks {
    return { msg => \&on_msg, public => \&on_public };
}

sub on_msg {
  my $conn = shift;
  my $event = shift;

  if($event->{args}[0] =~ /^${pluginchar}seen/) {
    seen($conn, $event, $event->nick);
  } elsif ($event->{args}[0] =~ /^${pluginchar}userinfo/) {
    userinfo($conn, $event, $event->nick);
  }
}

sub on_public {
  my $conn = shift;
  my $event = shift;

  if($event->{args}[0] =~ /^${pluginchar}seen/) {
    seen($conn, $event, $event->{to}[0]);
  }
}

sub userinfo {
    my $conn = shift;
    my $event = shift;
    my $who = shift;
    my @args = split(' ', ($event->args)[0]);
    my $user = host_to_user($event->nick.'!'.$event->userhost);

    if($args[0] eq "${pluginchar}userinfo") {
	if($args[1] eq 'help') {
	    $conn->privmsg($who, "UserInfo Plugin Version: $version");
	    $conn->privmsg($who, "Help:");

	    $conn->privmsg($who, "${pluginchar}seen <user> - returns user lastseen info");
	    $conn->privmsg($who, "syntax: /msg <botnick> ${pluginchar}seen <user>");

	    $conn->privmsg($who, "#userinfo commands / syntax: /msg <botnick> ${pluginchar}userinfo <password> <cmd> <args>");
	    $conn->privmsg($who, "password: /msg <botnick> <password> password <newpass>");
	    $conn->privmsg($who, "changes your password");
	    return;
	}
	if(!$user) {
	    $conn->privmsg($who, "You are not a user.");
	    return;
	}
	if(!$args[1]) {
	    $conn->privmsg($who, "Not nearly enough args... /msg <botnick> #userinfo help");
	    return;
	}

	if($args[1] eq $user->{password}) {
	    if($args[2] eq 'info') {
		if(!$args[3]) {
		    $conn->privmsg($who, "Not enough arguments for info...");
		    return;
		}
      		if(!$users{$args[3]}) {
		    $conn->privmsg($who, "$args[3] is not a user...");
		} else {
		    my $tempuser = $users{$args[3]};
		    
		    if(exists($tempuser->{allowed}{'realname'})) {
			$conn->privmsg($who, "$args[3]\'s realname: $tempuser->{realname}");
		    }
		    if(exists($tempuser->{allowed}{'workphone'})) {
			$conn->privmsg($who, "$args[3]\'s work phone: $tempuser->{workphone}");
		    }
		    if(exists($tempuser->{allowed}{'homephone'})) {
			$conn->privmsg($who, "$args[3]\'s home phone: $tempuser->{homephone}");
		    }
		    if(exists($tempuser->{allowed}{'email'})) {
			$conn->privmsg($who, "$args[3]\'s email: $tempuser->{email}");
		    }
		    if(exists($tempuser->{allowed}{'location'})) {
			$conn->privmsg($who, "$args[3]\'s location: $tempuser->{location}");
		    }
		    if(exists($tempuser->{allowed}{'mailingaddy'})) {
			$conn->privmsg($who, "$args[3]\'s mailing address: $tempuser->{mailingaddy}");
		    }
		}
	    }
	} else {
	    $conn->privmsg($who, "Password incorrect.");
	}
    }
}

sub seen {
    my $conn = shift;
    my $event = shift;
    my $who = shift;
    my @args = split(' ', ($event->args)[0]);

    foreach(values(%users)) {
	if($args[1] eq $_->{nick}) {
	    if($_->{lastseen} eq 'never') {


	      $conn->privmsg($who, "$args[1] last seen: " . $_->{lastseen});
	      return;
	    } else {
		my ($sec, $min, $hour, $mday, $mon, $year) = localtime($_->{lastseen});
		$year += 1900;
		$mon++;
		
		my $time = sprintf("%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
		
		$conn->privmsg($who, "$args[1] last seen: $time");
		return;
	    }
	}
    }
    $conn->privmsg($who, "$args[1] not a user.");
}

1;












