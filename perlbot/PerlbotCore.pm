package PerlbotCore;

# This is actually a plugin that contains the core perlbot functionality.
# It's always the first plugin to be loaded.  We need to perform a couple
# of tricks to make it appear like a plugin even though it's not in a subdir
# under the plugins dir.  :)

use strict;
use vars qw($hooks $CONFIG @noload);
use Perlbot;
use Chan;
use Logs;
use User;

# We could put this in get_hooks but we'd need PerlbotCore:: in front of
# everything... this is a little easier to maintain.
$hooks = {
  'msg'            => \&on_msg,
  'endofmotd'      => \&on_connect,
  'nomotd'         => \&on_connect,
  'public'         => \&on_public,
  'join'           => \&on_join,
  'part'           => \&on_part,
  'caction'        => \&on_ctcp_action,
  'disconnect'     => \&on_disconnect,
  'cping'          => \&on_ctcp_ping,
  'cversion'       => \&on_ctcp_version,
  'nicknameinuse'  => \&on_nick_error,
  'nickcollision'  => \&on_nick_error,
  'mode'           => \&on_mode,
  'topic'          => \&on_topic,
  'nick'           => \&on_nick_change,
  'quit'           => \&on_quit,
  'kick'           => \&on_kick,
  'whoisuser'      => \&on_whoisuser,
  'whoischannels'  => \&on_whoischannels,
  'nosuchnick'     => \&dump_event
    
  };


# here's a trick
# ==========
package PerlbotCore::Plugin;

sub get_hooks {
  return $PerlbotCore::hooks;
}
# ==========
# we now return you to your regularly scheduled package

package PerlbotCore;


# ============================================================
# variables
# ============================================================

my $nick_append;
my $msglog;

# this is kinda beefy.  look at sub parse_main_config if you're confused.
my %config_handlers =
  (
   chan => sub {
     my $name = to_channel($_[0]->{name}[0]) if $_[0]->{name}[0];
     my $key = '';
     if($_[0]->{key}[0]) { $key = $_[0]->{key}[0]; }
     my $chan = new Chan($name, $_[0]->{flag}, $key);
     foreach my $op (@{$_[0]->{op}}) {
       $chan->add_op($op) if (exists($users{$op}));
     }
     if($_[0]->{logging}) {
       $chan->logging($_[0]->{logging}[0]);
     }
     $channels{$name} = $chan;
   },
   user => sub {
     my $name = $_[0]->{name}[0] if $_[0]->{name}[0];
     my $flags = join('',@{$_[0]->{flag}}) if $_[0]->{flag};
     my @new_hostmasks = @{@_[0]->{hostmask}} if @{@_[0]->{hostmask}};
     $users{$name} = new User($name, $flags, @new_hostmasks);
     if($users{$name}) {
       $users{$name}->{password} = $_[0]->{password}[0] if $_[0]->{password}[0];
       $users{$name}->{realname} = $_[0]->{realname}[0] if $_[0]->{realname}[0];
       $users{$name}->{workphone} = $_[0]->{workphone}[0] if $_[0]->{workphone}[0];
       $users{$name}->{homephone} = $_[0]->{homephone}[0] if $_[0]->{homephone}[0];
       $users{$name}->{email} = $_[0]->{email}[0] if $_[0]->{email}[0];
       $users{$name}->{location} = $_[0]->{location}[0] if $_[0]->{location}[0];
       $users{$name}->{mailingaddy} = $_[0]->{mailingaddy}[0] if $_[0]->{mailingaddy}[0];
       foreach my $allowed (split(' ', $_[0]->{allowed}[0])) {
	 $users{$name}->{allowed}{$allowed} = 1;
       }
     }
   },
   server => sub {
     my $server = $_[0]->{addr}[0];
     my $port = $_[0]->{port}[0];
     # if no port specified, default to 6667
     $port or $port = 6667;
     print "Adding server: $server:$port...\n" if $debug;
     push @servers, [$_[0]->{addr}[0], $port];
   },
   bot => sub {
     if($_[0]->{nick}) { @nicks = @{$_[0]->{nick}}; }
     # if no name given, default to 'perlbot'
     $nicks[0] or $nicks[0] = 'perlbot';
     $currentnick = $nicks[0];
 
     $nick_append = $_[0]->{nickappend}[0];
     # if no nick_append string given, default to '_'
     $nick_append or $nick_append = '_';
     
     $ircname = $_[0]->{ircname}[0];
     # default to 'imabot'
     $ircname or $ircname = 'imabot';

     $Logs::basedir = $_[0]->{logdir}[0];
     # if no basedir given, default to the current dir
     if($dirsep eq '/') {
       $Logs::basedir or $Logs::basedir = './logs';
     } else {
       $Logs::basedir or $Logs::basedir = $dirsep . 'logs';
     }

     $plugindir = $_[0]->{plugindir}[0];
     # if no plugindir given, default to 'plugins'
     if($dirsep eq '/') {
       $plugindir or $plugindir = './plugins';
     } else {
       $plugindir or $plugindir = $dirsep . 'plugins';
     }
     
     # grab the list of modules NOT to load
     if($_[0]->{noload}) { @noload = @{$_[0]->{noload}}; }

     # get crash log filename
     $crashlog = $_[0]->{crashlogdir}[0];
     if ($crashlog) {
       $crashlog .= $dirsep.'crashlog.txt';
     } else {
       $crashlog = 'crashlog.txt';
     }

     # prevent display of warn()'s
     local $SIG{__WARN__} = {};

     # get our command prefix
     $commandprefix = $_[0]->{commandprefix}[0];
     eval "/$commandprefix/";
     die "Invalid bot.commandprefix.  Try escaping punctuation characters." if $@;
     $commandprefix ||= '#';

     # get our plugin prefix
     $pluginprefix = $_[0]->{pluginprefix}[0];
     eval "/$pluginprefix/";
     die "Invalid bot.pluginprefix.  Try escaping punctuation characters." if $@;
     $pluginprefix ||= '!';
   }
   );

# beware: this one is huge!
# This is faster than using some form of switch statement.
# Check out the on_msg sub to find out how we use this beast.
my %command_handlers = 
  (
   help => sub {
     my ($conn, $from) = @_;
     notify_users($conn, 'help', "$from requested HELP");
     get_help(@_);
   },
   nick => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);	
     my $newnick = shift;
     if($newnick) {
       notify_users($conn, 'nick', "$from requested NICK change to $newnick");
       if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
	 $conn->nick($newnick);
         $currentnick = $newnick;
       } else {
	 $conn->privmsg($from, "You are not an owner.");
       }
     } else {
       $conn->privmsg($from, "Not enough arguments to #nick.");
     }
   },
   quit => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $quitmsg = join(' ', @_);
     notify_users($conn, 'quit', "$from requested QUIT");
     if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
       shutdown_bot($conn, $quitmsg);
     } else {
       $conn->privmsg($from, "You are not an owner.");
     }
   },
   join => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $chan = shift;
     notify_users($conn, 'join', "$from requested JOIN $chan");
     if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
       my $conf = parse_config($CONFIG);
       foreach my $chan_hash (@{$conf->{chan}}) {
	 if ($chan eq $chan_hash->{name}->[0]) {
	   &{$config_handlers{chan}}($chan_hash);
	   $channels{to_channel($chan)}->join($conn);
	   return;
	 }
       }
       $channels{to_channel($chan)} = new Chan(to_channel($chan));
       $channels{to_channel($chan)}->join($conn);
     } else {
       $conn->privmsg($from, "You are not an owner.");
     }
   },
   part => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $chan = to_channel($_[0]);
     notify_users($conn, 'part', "$from requested PART $chan");
     if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
       if($channels{$chan}) {
	 $channels{$chan}->part($conn);
	 delete $channels{$chan};

       } else {
	 $conn->privmsg($from, "I am not currently in $chan");
       }
     } else {
       $conn->privmsg($from, "You are not an owner.");
     }		 
   },
   cycle => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $chan = to_channel($_[0]);
     notify_users($conn, 'part', "$from requested CYCLE $chan");
     if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
       if($channels{$chan}) {
	 $channels{$chan}->part($conn);
	 delete $channels{$chan};

	 my $conf = parse_config($CONFIG);
	 foreach my $chan_hash (@{$conf->{chan}}) {
	   if ($chan eq $chan_hash->{name}->[0]) {
	     &{$config_handlers{chan}}($chan_hash);
	     $channels{to_channel($chan)}->join($conn);
	     return;
	   }
	 }
	 $channels{to_channel($chan)} = new Chan(to_channel($chan));
	 $channels{to_channel($chan)}->join($conn);
       } else {
	 $conn->privmsg($from, "I am not currently in $chan");
       }
     } else {
       $conn->privmsg($from, "You are not an owner.");
     }		 
   },
   listchans => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $channel_list;
     notify_users($conn, 'part', "$from requested LISTCHANS");
     foreach my $chan (keys(%channels)) {
       $chan =~ s/\#//g;
       $channel_list .= "$chan ";
     }
     $conn->privmsg($from, "channels: $channel_list");
   },
   say => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $chan = to_channel(shift);
     notify_users($conn, 'say', "$from requested SAY on $chan : \"" . join(' ', @_) . '"');
     if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
       $conn->privmsg($chan, join(' ', @_));
     } else {
       $conn->privmsg($from, "You are not an owner.");
     }
   },
   msg => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $to = shift;
     notify_users($conn, 'msg', "$from requested MSG to $to : \"" . join(' ', @_) . "\"");
     if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
       $conn->privmsg($to, join(' ', @_));
     } else {
       $conn->privmsg($from, "You are not an owner.");
     }
   },
   logging => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $chan = to_channel(shift);
     my $logging = shift;
     notify_users($conn, 'logging', "$from requested $chan LOGGING $logging");
     if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
       if ($channels{$chan}) {
         if($logging eq 'yes' or $logging eq 'no') {
           $channels{$chan}->logging("$logging");
         }
         if($logging eq 'on') {
           $channels{$chan}->logging("yes");
         } 
         if($logging eq 'off') {
           $channels{$chan}->logging("no");
         }
         # ugly, ugly hacks make the world go 'round
       } else {
         $conn->privmsg($from, "Not in channel $chan.");
       }
     } else {
       $conn->privmsg($from, "You are not an owner.");
     }		 
   },
   server => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my ($addr, $user_port) = (shift, shift);
     my $port;
     $port = $user_port or $user_port = 6667;  # default to 6667
     notify_users($conn, 'server', "$from requested SERVER $addr:$user_port");
     if (host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
       if ($addr) {
         push @servers, [$addr, $port];
         $conn->server("$addr:$port");
         $conn->connect();
       } else {
         $conn->privmsg($from, "You must specify a server address.");
       }
     } else {
       $conn->privmsg($from, "You are not an owner.");
     }		 
   },
   reload => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     notify_users($conn, 'reload', "$from requested RELOAD");
     if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {	     
       &parse_main_config;
     } else {
       $conn->privmsg($from, "You are not an owner.");
     }
   },
   load => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $newconf = shift;
     if ($newconf) {
       if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {	     
	 notify_users($conn, 'load', "$from requested LOAD $newconf");
	 parse_config($newconf);
       } else {
	 $conn->privmsg($from, "You are not an owner.");
       }
     } else {
       $conn->privmsg($from, "Not enough arguments to #load.");
     }
   },
   redir => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     if(@_ < 2) {
       $conn->privmsg($from, "not enough arguments to #redir");
	 } else {
	   notify_users($conn, 'redir', "$from requested REDIR $_[0] $_[1]");
	   if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {
	     my $source = shift;
	     if(exists($channels{to_channel($source)})) {
	       $channels{to_channel($source)}->add_redir($_[0]);
	       $conn->privmsg($from, "added $_[0] to " . $source . "'s list of redirects");
	     }
	   } else {
	     $conn->privmsg($from, "You are not an owner.");
	   }
	 }
   },
   delredir => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     notify_users($conn, 'delredir', "$from requested DELREDIR");
     if(@_ < 2) {
       $conn->privmsg($from, "not enough arguments to #delredir"); 
	 } else {
	   if(host_to_user($userhost) && host_to_user($userhost)->{flags} =~ /w/) {	     
	     my $source = shift;
	     if(exists($channels{to_channel($source)})) {
	       $channels{to_channel($source)}->del_redir(@_);
	     }
	   } else {
	     $conn->privmsg($from, "You are not an owner.");
	   }
	 }
   },
   note => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     if (@_ < 2) {
       $conn->privmsg($from, "#note: not enough params!");
       return;
     }
     my $to = shift;
     print "from $from, to $to: @_\n" if $debug;
     if (exists($users{$to})) {
       $users{$to}->add_note($from, join(' ', @_));
       $conn->privmsg($from, "note added for $to\n");
     } else {
       $conn->privmsg($from, "#note: I don't know the user '$to'");
     }
   },
   listnotes => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my @temp_text;
     if (host_to_user($userhost)) {
       host_to_user($userhost)->listnotes($conn);
     }
   },
   readnote => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     if (host_to_user($userhost)) {
       host_to_user($userhost)->readnote($conn, @_);
     }
   },
   op => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $channel = to_channel(shift);
     my $user = host_to_user($userhost);
     my $username = username($user);

     if(!$channel) {
       $conn->privmsg($from, "usage: ${commandprefix}op <channel>");
       return;
     }

     if(!$user) {
       $conn->privmsg($from, "You are not a known user, perhaps you need to ${commandprefix}auth?");
       return;
     }

     if(!$channels{$channel}) {
       $conn->privmsg($from, "No such channel: $channel");
       return;
     }

     if(!exists($channels{$channel}->ops->{$username})) {
       $conn->privmsg($from, "You are not a valid op for channel $channel");
       return;
     } else {
        $conn->mode($channel, "+o", $from);
     }
   },
   auth => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $username = shift;
     my $password = shift;

     if(!$username || !$password || $password eq "''") {
       $conn->privmsg($from, "usage: ${commandprefix}auth <username> <password>");
       return;
     }

     if(exists($users{$username})) {
       if($users{$username}->password() && (crypt($password, $users{$username}->password()) eq $users{$username}->password())) {
         $users{$username}->hostmasks($userhost); # add this hostmask
         $conn->privmsg($from, "User $username authenticated");
       } else {
         $conn->privmsg($from, "Bad password");
       }
     } else {
       $conn->privmsg($from, "No such user: $username");
       return;
     }
   },
   password => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $newpassword = shift;
     my $user = host_to_user($userhost);
     my $username = username($user);

     if(!$newpassword) {
       $conn->privmsg($from, "Must specify a new password!");
       return;
     }

     if(!$user) {
       $conn->privmsg($from, "Not a known user, try auth first!");
       return;
     }

     if(!$username) {
       $conn->privmsg($from, "error in password: !username, tell your bot admin");
       return;
     }

     # FIXME:  This will break if someone has #loaded and is working from
     # a different config, basically if we #load a config, we should
     # probably reset $CONFIG
     my $tmpconfig = parse_config($CONFIG);
     my $usertomodify;
     foreach my $tempuser (@{$tmpconfig->{'user'}}) {
       if($tempuser->{'name'}[0] eq $username) {
         $usertomodify = $tempuser;
         last;
       }
     }

     if(!$usertomodify) {
       $conn->privmsg($from, "error in password: !usertomodify, tell your bot admin");
       return;
     }

     $newpassword =  crypt($newpassword, join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64]);
     $usertomodify->{'password'}[0] = $newpassword;
     write_config($CONFIG, $tmpconfig);
     $user->password($newpassword);

     $conn->privmsg($from, "Password successfully changed");
   },
   hostmasks => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $user = host_to_user($userhost);
     my $username = username($user);

     if(!$user) {
       $conn->privmsg($from, "Not a known user, try auth first!");
       return;
     }

     if(!$username) {
       $conn->privmsg($from, "error in hostmasks: !username, tell your bot admin");
       return;
     }

     # FIXME:  This will break if someone has #loaded and is working from
     # a different config, basically if we #load a config, we should
     # probably reset $CONFIG
     my $tmpconfig = parse_config($CONFIG);
     my $userfromconfig;
     foreach my $tempuser (@{$tmpconfig->{'user'}}) {
       if($tempuser->{'name'}[0] eq $username) {
         $userfromconfig = $tempuser;
         last;
       }
     }

     if(!$userfromconfig) {
       $conn->privmsg($from, "error in hostmasks: !userfromconfig, tell your bot admin");
       return;
     }

     foreach my $hostmask (@{$userfromconfig->{'hostmask'}}) {
       $conn->privmsg($from, $hostmask);
     }
     
   },
   addhost => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $hostname = shift;
     my $user = host_to_user($userhost);
     my $username = username($user);

     if(!$hostname) {
       $conn->privmsg($from, "Must specify a hostname!");
       return;
     }

     if(!$user) {
       $conn->privmsg($from, "Not a known user, try auth first!");
       return;
     }

     if(!$username) {
       $conn->privmsg($from, "error in addhost: !username, tell your bot admin");
       return;
     }

     # FIXME:  This will break if someone has #loaded and is working from
     # a different config, basically if we #load a config, we should
     # probably reset $CONFIG
     my $tmpconfig = parse_config($CONFIG);
     my $usertomodify;
     foreach my $tempuser (@{$tmpconfig->{'user'}}) {
       if($tempuser->{'name'}[0] eq $username) {
         $usertomodify = $tempuser;
         last;
       }
     }

     if(!$usertomodify) {
       $conn->privmsg($from, "error in addhost: !usertomodify, tell your bot admin");
       return;
     }

     my $unmodifiedhostname = $hostname;
     push(@{$usertomodify->{'hostmask'}}, $hostname);
     write_config($CONFIG, $tmpconfig);
     $user->hostmasks($hostname);
     
     $conn->privmsg($from, "Added $unmodifiedhostname to your list of hostmasks");
   },
   delhost => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     my $hostname = shift;
     my $user = host_to_user($userhost);
     my $username = username($user);

     if(!$hostname) {
       $conn->privmsg($from, "Must specify a hostname!");
       return;
     }

     if(!$user) {
       $conn->privmsg($from, "Not a known user, try auth first!");
       return;
     }

     if(!$username) {
       $conn->privmsg($from, "error in delhost: !username, tell your bot admin");
       return;
     }

     # FIXME:  This will break if someone has #loaded and is working from
     # a different config, basically if we #load a config, we should
     # probably reset $CONFIG
     my $tmpconfig = parse_config($CONFIG);
     my $usertomodify;
     foreach my $tempuser (@{$tmpconfig->{'user'}}) {
       if($tempuser->{'name'}[0] eq $username) {
         $usertomodify = $tempuser;
         last;
       }
     }

     if(!$usertomodify) {
       $conn->privmsg($from, "error in delhost: !usertomodify, tell your bot admin");
       return;
     }

     my $whichhost = 0;
     foreach my $hostmask (@{$usertomodify->{'hostmask'}}) {
       if($hostname eq $hostmask) {
         last;
       }
       $whichhost++;
     }

     if($whichhost > @{$usertomodify->{'hostmask'}}) {
       $conn->privmsg($from, "$hostname not in your list of hostmasks!");
       return;
     }

     splice(@{$usertomodify->{'hostmask'}}, $whichhost, 1);
     write_config($CONFIG, $tmpconfig);

     splice(@{$user->{hostmasks}}, $whichhost, 1);

     $conn->privmsg($from, "Removed $hostname from your list of hostmasks");

   },
   plugins => sub {
     my ($conn, $from, $userhost) = (shift, shift, shift);
     if (!@_) {
       # no params, so return a list of plugins
       $conn->privmsg($from, 'plugins: '.join(' ', @plugins));
       return;
     }
     my $user = host_to_user($userhost);
     if (!$user or $user->flags !~ /w/) {
       # not an owner!
       $conn->privmsg($from, 'You\'re not an owner!');
       return;
     }
     my $command = shift;
     my $param = shift;
     # strip off non alphanumerics to play it safe -- $param will be used
     # in an eval() later on
     $param =~ s/\W//g;
     if ($command eq 'load' or $command eq 'start') {	     
       if (!$param) {
	 $conn->privmsg($from, 'You need to specify a plugin to load');
	 return;
       }
       #make sure it's not already loaded
       if (!grep {/^$param$/} @plugins) {
	 if (validate_plugin($param) and load_one_plugin($param)) {
	   start_plugin($param);
	   $conn->privmsg($from, "Successfully loaded '$param'");
	 } else {
	   $conn->privmsg($from, "Couldn't load '$param'");
	 }
       } else {
	 $conn->privmsg($from, "'$param' is already loaded");
       }
     } elsif ($command eq 'unload' or $command eq 'stop') {
       if (!$param) {
	 $conn->privmsg($from, 'You need to specify a plugin to unload');
	 return;
       }
       # make sure it IS already loaded
       if (grep {/^$param$/} @plugins) {
	 if (unload_one_plugin($param)) {
	   $conn->privmsg($from, "Successfully unloaded '$param'");
	 } else {
	   $conn->privmsg($from, "Couldn't unload '$param'");
	 }
       } else {
	 $conn->privmsg($from, "'$param' isn't currently loaded");
       }
     } elsif ($command eq 'reload' or $command eq 'restart') {
       if (!$param) {
	 $conn->privmsg($from, 'You need to specify a plugin to reload');
	 return;
       }
       # make sure it IS already loaded
       if (grep {/^$param$/} @plugins) {
	 if (unload_one_plugin($param)) {
	   if (validate_plugin($param) and load_one_plugin($param)) {
	     start_plugin($param);
	     $conn->privmsg($from, "Successfully reloaded '$param'");
	   } else {
	     $conn->privmsg($from, "Couldn't load '$param'");
	   }
	 } else {
	   $conn->privmsg($from, "Couldn't unload '$param'");
	 }
       } else {
	 $conn->privmsg($from, "'$param' isn't currently loaded");
       }
     } elsif ($command eq 'reloadall' or $command eq 'restartall') {
     } else {
       $conn->privmsg($from, "Unknown #plugins command '$command'");
	 }
   }
   );


# ============================================================
# event handlers
# ============================================================

sub on_connect {
  my $self = shift;
  
  foreach (values(%channels)) {
    my $chan = $_->{name};
    print "Joining $chan\n" if $debug;
    $_->join($self);
  }
  
  $msglog = new Logs("msg");
}

sub on_msg {
  my ($self, $event) = (shift, shift);
  
  update_user($self, $event->nick, $event->userhost);
  
  if($msglog) { $msglog->write('<' . $event->nick . '!' . $event->userhost . '> ' . $event->{args}[0]); }
  
  if(($event->args)[0] =~ /^$commandprefix.*/) {
    # split text (on whitespace) into words
    my @commands = split(';', $event->{args}[0]);
    foreach my $command (@commands) {
      my @params = split (' ', $command);
      # shift off the command and strip the leading #
      my ($tmpcommand) = (shift @params) =~ /^$commandprefix(.*)/;
      # see if we have a handler for this command
      if (exists($command_handlers{$tmpcommand})) {
	# 3rd param is standard IRC nick!ident@host string
	&{$command_handlers{$tmpcommand}}($self, $event->nick, $event->nick.'!'.$event->userhost, @params);
      }
    }
  }
}

sub on_public {
  my ($self, $event) = (shift, shift);
  my $nick = $event->nick;
  my $chan = ($event->to)[0];
  my $text = ($event->args)[0];
  
  update_user($self, $event->nick, $event->userhost);
 
  if(exists($channels{to_channel($chan)})) {
    $channels{to_channel($chan)}->log_write("<$nick> $text");
    $channels{to_channel($chan)}->send_redirs($self, $nick, $text);
  }
}

sub on_join {
  my ($self, $event) = @_;
  my $user;
  my $nick = $event->nick;
  my $chan = ($event->to)[0]; #don't ask me, yo...
  
  $user = update_user($self, $nick, $event->userhost);
  $chan = to_channel($chan);
  
  if(exists($channels{$chan})) {
    $channels{$chan}->log_write("$nick (".$event->userhost.") joined $chan");
  }
  
  if($user) {
    if(exists($channels{$chan})) {
      my $usernick = $user->nick;
      my $ref = $channels{$chan}->ops;
      
      if(exists($ref->{$usernick})) {
	$self->mode($chan, "+o", $nick);
      }
    }
  }

# this should only happen when the bot is opped, i think

#  if(exists($channels{$chan})) {
#      $self->mode($chan, $channels{$chan}->{flags});
#  }

}

sub on_part {
  my ($self, $event) = @_;
  my $nick = $event->nick;
  my $chan = ($event->to)[0];
  
  update_user($self, $event->nick, $event->userhost);
  if(exists($channels{to_channel($chan)})) {
    $channels{to_channel($chan)}->log_write("$nick (".$event->userhost.") left $chan");
  }
}

sub on_ctcp_action {
  my ($self, $event) = @_;
  my $nick = $event->nick;
  my $chan = ($event->to)[0];
  my $text = join(' ', @{$event->{args}});

  update_user($self, $event->nick, $event->userhost);
  if(exists($channels{to_channel($chan)})) {
    $channels{to_channel($chan)}->log_write("$nick $text");
  }
}

sub on_topic {
  my $self = shift;
  my $event = shift;
  my $nick = $event->nick;
  my $chan = $event->{to}[0];

  update_user($self, $event->nick, $event->userhost);
  if(exists($channels{to_channel($chan)})) {
    $channels{to_channel($chan)}->log_write("[TOPIC] $nick: " . $event->{args}[0]);
  }
}

sub on_nick_change {
  my $self = shift;
  my $event = shift;
  my $nick = $event->{args}[0]; #this is their NEW nick...
  my $host = $nick . '!' . $event->userhost;

  update_user($self, $nick, $event->userhost);

  my $user = host_to_user($host);

  if($user) {
    foreach my $chan (@{$user->{curchans}}) {
      if(exists($channels{to_channel($chan)})) {
	$channels{to_channel($chan)}->log_write("[NICK] " . $event->nick . " changed nick to: $nick");
      }
    }
  }
}

sub on_quit {
  my $self = shift;
  my $event = shift;
  my $nick = $event->nick;
  my $host = $nick . '!' . $event->userhost;

  update_user($self, $event->nick, $event->userhost);

  my $user = host_to_user($host);

  if($user) {
    foreach my $chan (@{$user->{curchans}}) {
      if(exists($channels{to_channel($chan)})) {
	$channels{to_channel($chan)}->log_write("[QUIT] $nick quit: " . $event->{args}[0]);
      }
    }
  }
}

sub on_kick {
  my $self = shift;
  my $event = shift;
  my $nick = $event->nick;
  my $who = $event->{to}[0];
  my $chan = $event->{args}[0];

  update_user($self, $event->nick, $event->userhost);
  if(exists($channels{to_channel($chan)})) {
    $channels{to_channel($chan)}->log_write("[KICK] $who was kicked by $nick (" . $event->{args}[1] . ')');
  }
}

sub on_whoisuser {
  my $self = shift;
  my $event = shift;
  my $nick = $event->{args}[0];
  my $host = join('@', $event->{args}[2], $event->{args}[3]);

  # do nothing...
}

sub on_whoischannels {
  my $self = shift;
  my $event = shift;
  my $nick = $event->{args}[1];
  my $user = '';

  foreach(values(%users)) {
    if($_->{curnick} eq $nick) { $user = $_; }
  }

  if($user ne '') {
    $user->update_channels($event->{args}[2]);
  }
}

sub on_disconnect {
  my ($self, $event) = @_;
  my $old_server = $event->{from};
  my $server;
  my $i;
  
  if($$ == 0) {    # exit if we're a child...
    exit;
  }
  
  if($debug) {
    print "Disconnected from: $old_server\n";
    $event->dump();
    print "---End dump...\n";
  }
  
  while(!$self->connected()) {
    for($i = 0; $i<@servers; $i++) {
      if($servers[$i]->[0] eq $old_server) { $i++; last; }
      if($i == @servers - 1) { $i = 0; $old_server = ''; last; }
    }
    
    for($i; $i<@servers; $i++) {
      $server = join(':', $servers[$i]->[0], $servers[$i]->[1]);
      print "trying $server\n" if $debug;
      $self->server($server);
      $self->connect();
      if($self->connected()) {
	return;
      }
      if($i == @servers - 1) { last; }
    }
    
    print "Sleeping for 10 seconds...\n" if $debug;
    sleep(10);
    $i = 0;
    $old_server = '';
  }
}
	
sub on_ctcp_ping {
  my ($self, $event) = @_;
  my $nick = $event->nick;
  
  update_user($self, $event->nick, $event->userhost);
  $self->ctcp_reply($nick, join (' ', ($event->args)));
}

sub on_ctcp_version {
  my ($self, $event) = @_;
  my $nick = $event->nick;
  
  update_user($self, $event->nick, $event->userhost);
  $self->ctcp_reply($nick, "VERSION Perlbot version: $VERSION / by: $AUTHORS");
}

sub on_nick_error {
  my ($self, $event) = @_;
  my $use_this_one = 0;
  
  print "nick error...\n" if $debug;
  
  if(@nicks < 2) {
    $nicks[0] = $nicks[0] . $nick_append;
    $self->nick($nicks[0]);
    $currentnick = $nicks[0];
  } else {
    foreach(@nicks) {
      if($use_this_one) {
	$self->nick($_);
        $currentnick = $_;
	return;
      } else {
	if($_ eq $self->nick()) {
	  $use_this_one = 1;
	  next;
	}
      }
    }
    
    # if every nickname we like is in use... we do this...
    $nicks[0] = $nicks[0] . $nick_append;
    $self->nick($nicks[0]);
    $currentnick = $nicks[0];
  }
}

sub on_mode {
  my $conn = shift;
  my $event = shift;
  my $chan = to_channel($event->{to}[0]);

  # log the mode change
  if(exists($channels{$chan})) {
    $channels{$chan}->log_write(
      '[MODE] ' . $event->nick . ' set mode: ' . join(' ', @{$event->{args}})
    );
  }

  # if I got opped, set the channel mode in case it got changed
  if(($event->{args}[1] eq $conn->nick) && ($event->{args}[0] =~ /\+o/)) {
    if(exists($channels{$chan})) {
      $conn->mode($chan, $channels{$chan}->{flags});
      # op the channel ops if they're not already opped
      # foreach($channels{$chan}->{ops}) {
      #   if
    }
  }

}

# ============================================================
# other misc utility subs
# ============================================================

# Params:
#   1) file name for main config file
# Returns:
#   If there was some error : an error string
#   If there was no error   : undef
sub parse_main_config {
  my $ret = parse_config($CONFIG);
  # If $ret isn't a hash ref, it's an error string... :(
  if (ref($ret) ne 'HASH') {
    print $ret, "\n";
    exit(1);
  }
  
  # This is less robust that iterating over keys(%$ret).  However,
  # it removes any ordering requirements in the config file, AND it
  # fixes what we broke by originally using keys(%$ret) (namely everything
  # to do with users and channels).
  # -> Special thanks to Christian Mogensen <christian@superoffice.no> for
  #    the nicer fix to this... (putting the strings in an array, instead
  #    of having a separate 'foreach my $fields' loop for each string :)
  foreach my $class ('user','bot','server','chan') {
    foreach my $fields (@{$ret->{$class}}) {
      &{$config_handlers{$class}}($fields);
    }
  }
  
  # Die if critical things haven't been set, and warn if other important
  # but non-critical things haven't been set.
  %channels or print "WARNING: No channels specified.  Is this really what you want?\n";
  %users or print "WARNING: No users specified.  Is this really what you want?\n";
  if (!@servers) {
    print "FATAL: No servers specified.  You need at least one server.\n";
    exit(1);
  }
}

sub get_help {
  my ($conn, $from, $userhost) = (shift, shift, shift);
  my ($plugin, $topic) = (shift, shift);
  my $plugname;
  my $helpfile = new IO::File;
  
  if ($plugin) {
    if (($plugname) = grep(/^\Q$plugin\E$/i, @plugins)) {
      if (! $helpfile->open("<$plugindir" . $dirsep . "$plugname" . $dirsep . 'help.txt')) {
	$conn->privmsg($from, "I can't open the help file for plugin '$plugname'");
      } else {
	extract_help($helpfile, $plugname, $topic, $conn, $from);
      }
    } elsif (lc($plugin) eq 'core') {
      if (! $helpfile->open("<help.txt")) {
	$conn->privmsg($from, "I can't open the main help file");
      } else {
	extract_help($helpfile, 'Core', $topic, $conn, $from);
      }
    } else {
      $conn->privmsg($from, "I don't have plugin '$plugin' loaded");
    }
  } else {
    $conn->privmsg($from, "syntax: #help [plugin [topic]]");
    $conn->privmsg($from, "Returns help for the specified plugin and topic.".
		   "  If no topic is given, returns the plugin's general help message".
		   " and a list of topics you can ask about.");
    $conn->privmsg($from, "PLUGINS: ".join(' ', 'Core', @plugins[1..$#plugins]));
  }
}

sub extract_help {
  my ($helpfile, $plugin, $topic, $conn, $from) = @_;
  my (@help, %help, $rawtext, $basehelp);
  
  @help = grep(/^.+$/, $helpfile->getlines);
  chomp @help;
  $basehelp = shift(@help);
  %help = @help;
  $help{''} = $basehelp;
  unless ($rawtext = $help{$topic}) {
    $conn->privmsg($from, "I don't have any help for plugin '$plugin' on topic '$topic'");
  } else {
    foreach my $line (split(/\\\\/, $rawtext)) {
      $conn->privmsg($from, $line);
    }
    if (! $topic) {
      my @realtopics = sort(grep(/.+/, keys(%help)));
      if (@realtopics) {
	$conn->privmsg($from, "SUBTOPICS: ".join(' ', @realtopics));
      }
    }
  }
}

# this just takes an event and dumps it to stdout...

sub dump_event {
  my $self = shift;
  my $event = shift;

  $event->dump() if $debug;
}

1;
