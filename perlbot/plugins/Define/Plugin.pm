# Andrew Burke <burke@pas.rochester.edu>
#
# this is fearable, and ugly... maybe i'll comment it someday...

package Define::Plugin;

use Perlbot;
use POSIX;

sub get_hooks {
  return { public => \&on_public, msg => \&on_msg };
}

sub on_public {
    my ($conn, $event) = @_;
    do_processing($conn, $event, ($event->to)[0]);
}

sub on_msg {
    my ($conn, $event) = @_;
    do_processing($conn, $event, $event->nick);
}

sub do_processing {
  my ($conn, $event, $who) = @_;
  my $userhost = $event->nick.'!'.$event->userhost;
  
  my $args;
  ($args = ($event->args)[0]) =~ tr/[A-Z]/[a-z]/;

  if ($args =~ /^${pluginchar}define/) {
    if(host_to_user($userhost)) {
      if(($event->args)[0] !~ /:/) {
	$conn->privmsg($who, "syntax: ${pluginchar}define <term> : <definition>");
	return;
      }
      define($conn, $event, $who);
    } else {
      $conn->privmsg($who, $event->nick . ': you do not have privileges to modify the database.');
      return;
    }
    return;
  }

  if ($args =~ /^${pluginchar}redefine/) {
    if(host_to_user($userhost)) {
      if(($event->args)[0] !~ /:/) {
	$conn->privmsg($who, "syntax: ${pluginchar}redefine <term> : <definition>");
	return;
      }
      redefine($conn, $event, $who);
    } else {
      $conn->privmsg($who, $event->nick . ", you do not have privileges to modify the database.");
      return;
    }
    return;
  }

  if ($args =~ /^${pluginchar}(?:lookup|whatis)/) {
    lookup($conn, $event, $who);
    return;
  }

  # ignore other ! and # commands to be polite
  if($args =~ /^[${pluginchar}\${commandchar}]/) {
    return;
  }

  # by this point, $args will definitely not contain a ! or # command

  my $connector;
  my $action;
  my $text = '';

  if (($text) = $args =~
    /(?:(?:what|who|wtf|where)\s+(?:.*?\s+)?(?:is|are)|where\'s|what\'s|tell\s+me\s+(?:about|of)|help(?:\s+(?:me)?\s+with)?)\s+([^?!.]*)/) {
    $connector = 'is';
  } elsif (($text, $action) = $args =~ /what\s+.*?does\s+(.*?)\s+(mean|stand\s+for)/) {
    if ($action =~ /mean/) {
      $connector = 'means';
    } else {
      $connector = 'stands for';
    }
  }

  if ($text) {
      special_case_hack($conn, $who, $text, $connector);
  }
}

sub define {
  my $conn = shift;
  my $event = shift;
  my $who = shift;

  my %dict;

  if (!defined($pid = fork)) {
    $conn->privmsg($who, "error in define, or something...");
    $conn->{_connected} = 0;
    exit 1;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...
    
    my $args = (split(' ', $event->{args}[0], 2))[1];
    
    my($term, $def) = split(':', $args, 2);
    
    $term = lc($term);
    $term =~ s/^\s*(.*?)\s*$/\1/;
    chomp $term;
    
    $def =~ s/^\s*(.*?)\s*$/\1/;
    chomp $def;

    open DB, "<$plugindir/Define/defs.db";
    my @lines = <DB>;
    chomp @lines;
    %dict = @lines;
    close DB;

    if (exists($dict{$term})) {
      $conn->privmsg($who, "$term already in database.");
    } else {
      $dict{$term} = $def;

      open DB, ">$plugindir/Define/defs.db";
      print DB join("\n", %dict);
      close DB;

      $conn->privmsg($who, "$term added to database.");
    }

    $conn->{_connected} = 0;
    exit 0;
  }    
}

sub redefine {
  my $conn = shift;
  my $event = shift;
  my $who = shift;

  my %dict;

  if (!defined($pid = fork)) {
    $conn->privmsg($who, "error in define, or something...");
    $conn->{_connected} = 0;
    exit 1;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...
    
    my $args = (split(' ', $event->{args}[0], 2))[1]; # leave off ! command

    my ($term, $def) = split(':', $args, 2);
    
    $term = lc($term);
    $term =~ s/^\s*(.*?)\s*$/\1/;
    chomp $term;  # necessary?
    
    $def =~ s/^\s*(.*?)\s*$/\1/;
    chomp $def;   # necessary?

    open DB, "<$plugindir/Define/defs.db";
    my @lines = <DB>;
    chomp @lines;
    %dict = @lines;
    close DB;

    if (exists($dict{$term})) {
      $dict{$term} = $def;

      open DB, ">$plugindir/Define/defs.db";
      print DB join("\n", %dict);
      close DB;

      $conn->privmsg($who, "$term redefined in database.");
    } else {
      $conn->privmsg($who, "$term not yet defined. Try ${pluginchar}define.");
    } 

    $conn->{_connected} = 0;
    exit 0;
  }
}

sub lookup {
  my $conn = shift;
  my $event = shift;
  my $who = shift;

  my %dict;

  if (!defined($pid = fork)) {
    $conn->privmsg($who, "error in lookup, or something...");
    $conn->{_connected} = 0;
    exit 1;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...
    
    my $args = (split(' ', ($event->args)[0], 2))[1]; # leave off the ! command
    $args = lc($args);
    chomp $args;  # is this necessary?
       
    open DB, "<$plugindir/Define/defs.db";
    my @lines = <DB>;
    chomp @lines;
    %dict = @lines;
    close DB;

    if (exists($dict{$args})) {
      $conn->privmsg($who, "$args : $dict{$args}");
    } else {
      $conn->privmsg($who, "$args not defined in the database.");
    }

    $conn->{_connected} = 0;
    exit 0;
  }
}

sub special_case_hack {
  my ($conn, $who, $args, $reply_connector) = @_;
  my %dict;

  if (!defined($pid = fork)) {
    $conn->privmsg($who, "error in lookup, or something...");
    $conn->{_connected} = 0;
    exit 1;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = sub { wait; };
    return;

  } else {
    # child...
    
    $args = lc($args);
    chomp $args;
    my @words = split(' ', $args);
       
    open DB, "<$plugindir/Define/defs.db";
    my @lines = <DB>;
    chomp @lines;
    %dict = @lines;
    close DB;

    my $matches = 0;
    my $tempmatches = 0;
    my $key = '';
    my $tempkey;
    my $matched_section;
    my $tmpmatched_section;
    foreach $tempkey (keys(%dict)) {
      if($tempkey eq join(' ', @words)) {
        $key = $tempkey;
        $matched_section = $key;
        last;
      }

      foreach my $word (@words) {
	# the \Q and \E keep
	# $word from being used
	# as a regexp
	if($tempkey =~ /\Q$word\E/) {
	  $tempmatches++;
	  $tmpmatched_section = $tmpmatched_section . $word;
	}
      }
      if($tempmatches >= $matches) {
	if(($key ne '') && (@words < split(' ', $tempkey))) {
	  $tempmatches = 0;
	  $tmpmatched_section = '';
	  next;
	}
	if($tempmatches) {
	  $key = $tempkey;
	  $matches = $tempmatches;
	  $matched_section = $tmpmatched_section;
	}
      }
      $tempmatches = 0;
      $tmpmatched_section = '';
    }

    my $clean_key = $key;
    $clean_key =~ s/ //g;

    if(length($clean_key) > 0) {
      my $matchstrength = length($matched_section) / length($clean_key);
      my $unmatchedstrength = length(join('', @words)) / length ($clean_key);

#      print "<$key> matched <" . join(' ', @words) . "> with strength: " . $strength . " (" . length($matched_section) . " / " . length($clean_key) . " )\n" if $debug;

      if(($matchstrength > .5) && ($unmatchedstrength < 3.1)) {
	$conn->privmsg($who, "$key $reply_connector $dict{$key}");
      }
    }

    $conn->{_connected} = 0;
    exit 0;
  }  
}

1;
