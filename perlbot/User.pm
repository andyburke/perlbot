package User;

use Note;
use strict;
use Perlbot;


sub new {
    my $class = shift;
    my ($nick, $flags) = (shift, shift);
    my $curnick = $nick; #for now...

    my $self = {
	name	 => $nick,
	nick     => $nick,
	curnick  => $curnick,
	curchans => [],
	hostmasks => [],
	flags    => $flags,
	lastnick => undef,
	notes    => [],
	notified => 0,

	realname => '',
	workphone => '',
	homephone => '',
	email    => '',
	location => '',
	mailingaddy => '',
	
	lastseen => 'never',
	signoffmsg => '',

	password => '',
	allowed => {}
	
	};

    bless $self, $class;
    $self->hostmasks(@_);
    return $self;
}

sub name {
  my $self = shift;
  $self->{name} = shift if @_;
  return $self->{name};
}

sub nick {
    my $self = shift;
    $self->{nick} = shift if @_;
    return $self->{nick};
}

sub curnick {
    my $self = shift;
    $self->{curnick} = shift if @_;
    return $self->{curnick};
}

sub hostmasks {
    my $self = shift;
    my @hostmasks = @_;

    foreach my $hostmask (@hostmasks) {
        # make sure the hostmask is OK before adding it
	validate_hostmask($hostmask) or return;

        # Substitutions to take a standard IRC hostmask and convert it to
        #   a regexp.  I thought this was pretty clever...  :)

        # escape periods becuse they shouldn't be treated as wildcards
        $hostmask =~ s/\./\\./g;

        # * in a hostmask means "any string of chars" which becomes .* in a regexp
        $hostmask =~ s/\*/.*/g;

        # {}| are really the lowercase equivalents of []\  (Don't ask me... read RFC1459) 
        # The result of this is that { is equivalent to [ in a nick, etc.
        # I couldn't do a direct substitution for each of these.  There would
        #   be problems with the inserted ] and \ chars (used to define the
        #   character classes on the right side of the s///) being picked up
        #   by the second and third s/// expressions.  The solution was to
        #   substitute a character that would never be found in a real hostmask
        #   in a first pass, and convert those characters to the correct
        #   regexp in a second pass.
        # First pass: convert each instance of a char (upper or lower) to some
        #   'impossible' character.  (ascii 01, 02, and 03)
        $hostmask =~ s/[{[](?=.*!)/\01/g;
        $hostmask =~ s/[}\]](?=.*!)/\02/g;
        $hostmask =~ s/[|\\](?=.*!)/\03/g;
        # Second pass: convert each impossible char to the appropriate regexp
        $hostmask =~ s/\01/[{[]/g;
        $hostmask =~ s/\02/[}\\]]/g;
        $hostmask =~ s/\03/[|\\\\]/g;

        if(!grep { /^\Q$hostmask\E$/ } @{$self->{hostmasks}}) { # don't add duplicates
          push @{$self->{hostmasks}}, $hostmask;
        }
    }

    return $self->{hostmasks};
}

sub flags {
    my $self = shift;
    $self->{flags} = shift if @_;
    return $self->{flags};
}

sub notified {
    my $self = shift;
    $self->{notified} = shift if @_;
    return $self->{notified};
}

sub password {
    my $self = shift;
    $self->{password} = shift if @_;
    return $self->{password};
}

sub update_channels {
  my $self = shift;
  my $chans = shift;

  $chans =~ s/@//g;

  while(@{$self->{curchans}}) { pop @{$self->{curchans}}; }

  foreach my $chan (split(' ', $chans)) {
    push @{$self->{curchans}}, $chan;
  }
}
    

sub dump {
    my $self = shift;
    print <<END_DUMP;
User:
  name     : $self->{name}
  nick     : $self->{nick}
  hostmasks: @{$self->{hostmasks}}
  flags    : $self->{flags}
END_DUMP
}

sub listnotes {
    my $self = shift;
    my $priv_conn = shift;
    my $notestring = '';
    my $notenum = 1;

    if(@{$self->{notes}} == 0) {
	$priv_conn->privmsg($self->{curnick}, "No current notes.\n");
	return 1;
    }

    foreach(@{$self->{notes}}) {
	$notestring = $notestring . "$notenum) $_->{from} - $_->{date}\n";
	$priv_conn->privmsg($self->{curnick}, $notestring);
	$notenum++;
	$notestring = '';
    }
    return 1;
}	

sub readnote {
    my $self = shift;
    my $priv_conn = shift;
    my $notenum = shift;
    my $note;
    my $notetext = '';

    if(defined($notenum)) { $notenum--; } #change it to be a real index into the array

    if(@{$self->{notes}} == 0) {
	$self->{notified} = 0;
	$priv_conn->privmsg($self->{curnick}, "No more notes.\n");
	return 0;
    }

    if(defined($notenum)) {
	if($notenum >= 0 && @{$self->{notes}}[$notenum]) {
	    ($note) = splice(@{$self->{notes}}, $notenum, 1);
	    
	    $priv_conn->privmsg($self->{curnick}, "$note->{from} - $note->{date}:\n");
	    $priv_conn->privmsg($self->{curnick}, "  $note->{text}\n");
	} else {
	    $notenum++;
	    $priv_conn->privmsg($self->{curnick}, "No such note: $notenum\n");
	}
    } else {
	# notes should be a queue and not a stack, so use shift instead of pop
	$note = shift(@{$self->{notes}});

	if($note) {
	    $priv_conn->privmsg($self->{curnick}, "$note->{from} - $note->{date}:\n");
	    $priv_conn->privmsg($self->{curnick}, "  $note->{text}\n");
	}
    }

    return 1;
}

sub add_note {
    my $self = shift;
    my ($from, $text) = (shift, shift);
    my $note;

    if($from && $text) {
	$self->{notified} = 0;
	print "= saving note to $self->{name} from $from: $text\n" if ($debug);
	$note = new Note($from, $text);
	push @{$self->{notes}}, $note;
    }

    # return the current number of stored notes
    return scalar(@{$self->{notes}});
}

sub notes {
    my $self = shift;

    # return the current number of stored notes
    return scalar(@{$self->{notes}});
}

1;
