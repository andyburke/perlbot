package Perlbot::User;

use Perlbot::Note;
use strict;
use Perlbot::Utils;

sub new {
    my $class = shift;
    my ($nick, $flags, $password) = (shift, shift, shift);
    my @hostmasks = @_;
    my $curnick = $nick; #for now...

    my $self = {
	name	   => $nick,
	nick       => $nick,
	curnick    => $curnick,
	curchans   => [],
	hostmasks  => [],
        admin      => 0,
	flags      => $flags,
	lastnick   => undef,
	notes      => [],
	notified   => 0,

	realname   => '',
	workphone  => '',
	homephone  => '',
	email      => '',
	location   => '',
	mailaddr   => '',

	lastseen   => 'never',
	signoffmsg => '',

	password   => $password,
	allowed    => {}

	};

    bless $self, $class;
    $self->hostmasks(@hostmasks);
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

    $self or return undef;

    @hostmasks or return undef;

    foreach my $hostmask (@hostmasks) {
        # make sure the hostmask is OK before adding it
	if (!validate_hostmask($hostmask)) {
          print "User '$self->{name}': refusing to add invalid hostmask: $hostmask\n" if $DEBUG;
          return;
        }

        # Substitutions to take a standard IRC hostmask and convert it to
        #   a regexp.  I thought this was pretty clever...  :)

        # split hostmask into nick and userhost, since the rules differ
        my ($nick, $userhost) = $hostmask =~ /^(.*)!(.*)$/;

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
        $nick =~ s/[{[]/\01/g;
        $nick =~ s/[}\]]/\02/g;
        $nick =~ s/[|\\]/\03/g;
        # Second pass: convert each impossible char to the appropriate regexp
        $nick =~ s/\01/[{[]/g;
        $nick =~ s/\02/[}\\]]/g;
        $nick =~ s/\03/[|\\\\]/g;

        $userhost =~ s/([[\]{}|\\])/\\$1/g; # escape \[]{} only in userhost

        $hostmask = "$nick!$userhost";      # recombine
        $hostmask =~ s/([().?^\$])/\\$1/g;  # escape ().?^$
        $hostmask =~ s/\*/.*/g;             # translate wildchar "*" to regexp equivalent ".*"

        if(!grep { /^\Q$hostmask\E$/ } @{$self->{hostmasks}}) { # don't add duplicates
          push @{$self->{hostmasks}}, $hostmask;
        }
    }

    return $self->{hostmasks};
}

sub admin {
  my $self = shift;
  $self->{admin} = shift if @_;
  return $self->{admin};
}

sub is_admin {
  my $self = shift;
  return $self->admin();
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
    my $notestring = '';
    my $notenum = 1;

    if(@{$self->{notes}} == 0) {
      $notestring = 'No current notes.';
    } else {
      foreach(@{$self->{notes}}) {
        $notestring .= "$notenum) $_->{from} - $_->{date}\n";
        $notenum++;
      }
    }
    return $notestring;
}

sub readnote {
    my $self = shift;
    my ($notenum) = (shift =~ /(\d+)/);
    my $note;
    my $notetext = '';

    if(defined($notenum)) { $notenum--; } #change it to be a real index into the array

    if(@{$self->{notes}} == 0) {
        $self->{notified} = 0;
        $notetext = 'No more notes.';
    } else {
      if(defined($notenum)) {
        if($notenum >= 0 && @{$self->{notes}}[$notenum]) {
            ($note) = splice(@{$self->{notes}}, $notenum, 1);
            $notetext = "$note->{from} - $note->{date}:\n  $note->{text}";
        } else {
            $notenum++;
            $notetext = "No such note: $notenum";
        }
      } else {
        # notes should be a queue and not a stack, so use shift instead of pop
        $note = shift(@{$self->{notes}});

        if($note) {
          $notetext = "$note->{from} - $note->{date}:\n  $note->{text}";
        }
      }
    }
    
    return $notetext;
}

sub add_note {
    my $self = shift;
    my ($from, $text) = (shift, shift);
    my $note;

    if($from && $text) {
        $self->{notified} = 0;
        print "= saving note to $self->{name} from $from: $text\n" if ($DEBUG);
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
