# InfoBot-like plugin
#
# This is a shameless rip from the infobot code in a lot of ways
#
# Kevin Lenzo and friends are the ones responsible for this in the
# first place, check their stuff out at www.infobot.org

package Perlbot::Plugin::InfoBot;

use Perlbot::Utils;
use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use File::Spec;
use DB_File;

our $VERSION = '1.0.0';

sub init {
  my $self = shift;

  tie %{$self->{facts}},  'DB_File', File::Spec->catfile($self->{directory}, 'factsdb'), O_CREAT|O_RDWR, 0640, $DB_HASH;

  $self->load_dbs();

  $self->hook_addressed(\&addressed);
  $self->hook(\&normal);

}

sub load_dbs {
  my $self = shift;
  my $dbdir = File::Spec->catfile($self->{directory}, 'factpacks');

  opendir(DBDIR, $dbdir);
  my @dbfiles = readdir(DBDIR);
  close DBDIR;

  foreach my $dbfile (@dbfiles) {
    if($dbfile eq '.' or $dbfile eq '..') { next; }
    $self->load_db(File::Spec->catfile($dbdir, $dbfile));
  }

}

sub load_db {
  my $self = shift;
  my $db = shift;

  my $good  = 0;
  my $total = 0;
  my $collisions = 0;

  if(-d $db) {
    return;
  } else {
    debug("InfoBot loading $db...", 2);
    open(DBFILE, "<$db") or die "Couldn't open $db\n";

    while(my $line = <DBFILE>) {
      chomp $line;
      if(!$line) { next; }

      if($line =~ /^#.*/) {
        next;
      }

      if($line =~ /^.*?=>.*?/) {
        my ($term, $def) = ($line =~ /^\s*(.*?)\s*=>\s*(.*?)\s*$/);
#      $def =~ s/<reply>.*?,\s*//;
        if($self->{facts}{lc($term)}) { $collisions++; }
        $self->{facts}{lc($term)} = $def;
        $good++;
      }

      $total++;   
    }

    debug("  $good/$total good entries found", 2);
    debug("  $collisions collisions", 2);

    close DBFILE;

  }
}

sub addressed {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $term = $self->termify($text);
  my $def = $self->lookup($term);

  if($def) {
    $def =~ s/^<reply>.*?,\s+//;
    $self->addressed_reply($def);
  }

}

sub normal {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $term = $self->termify($text);
  my $def = $self->lookup($term);

  if($def) {
    if($def =~ /^<reply>/) {
      $def =~ s/^<reply>.*?,\s+//;
      $self->addressed_reply($def);
    } else {
      $self->reply($term . ' is ' . $self->{facts}{$term});
    }
  }
}


sub termify {
  my $self = shift;
  my $text = shift;

  my $term = " $text ";

  $term =~ s/(who|what|where)\'s/$1 is/i;

  # where blah is -> where is blah
  $term =~ s/(where|what|who)\s+(\S+)\s+(is|are)\s+/ $1 $3 $2 /i;
    
  # where blah is -> where is blah
  $term =~ s/(where|what|who)\s+(.*)\s+(is|are)\s+/ $1 $3 $2 /i;

  $term =~ s/(.*?)\s+(is|are)\s+(where|what|who)\s+/ $3 $2 $1 /i;
    
  $term =~ s/^\s*(.*?)\s*/$1/;
    
  $term =~ s/be tellin\'?g?/tell/i;
  $term =~ s/ \'?bout/ about/i;
    
  $term =~ s/,? any(hoo?w?|ways?)/ /ig;
  $term =~ s/,?\s*(pretty )*please\??\s*$/\?/i;
    
  # what country is ...
  if ($term =~ 
    s/wh(at|ich)\s+(add?res?s|country|place|net (suffix|domain))//ig) {
    if ((length($in) == 2) && ($term !~ /^\./)) {
      $term = 'what is .'.$term;
    }
    $term .= '?';
  }

  $term =~ s/th(e|at|is) (((m(o|u)th(a|er) ?)?fuck(in\'?g?)?|hell|heck|(god-?)?damn?(ed)?) ?)+//ig;
  $term =~ s/wtf/where/gi; 
  $term =~ s/this (.*) thingy?/ $1/gi;
  $term =~ s/does (.*) mean?/is $1/gi;
  $term =~ s/this thingy? (called )?//gi;
  $term =~ s/ha(s|ve) (an?y?|some|ne) (idea|clue|guess|seen) /know /ig;
  $term =~ s/does (any|ne|some) ?(1|one|body) know //ig;
  $term =~ s/do you know //ig;
  $term =~ s/can (you|u|((any|ne|some) ?(1|one|body)))( please)? tell (me|us|him|her)//ig;
  $term =~ s/where (\S+) can \S+ (a|an|the)?//ig;
  $term =~ s/(can|do) (i|you|one|we|he|she) (find|get)( this)?/is/i; # where can i find
  $term =~ s/(i|one|we|he|she) can (find|get)/is/gi; # where i can find
  $term =~ s/(the )?(address|url) (for|to) //i; # this should be more specific
  $term =~ s/(where is )+/where is /ig;
  $term =~ s/is a\s+/is /ig;
  $term =~ s/is an\s+/is /ig;
  $term =~ s/^\s+//;
    
  $term =~ s/\s+/ /g;
    
  $term =~ s/^\s*(.*?)\s*$/$1/;

  $term = lc($term);

  if($term =~ /(?:what|where|who) is/ || $term =~ /\?$/) {
    $term =~ s/.*?is\s+(.*?)$/$1/;
    $term =~ s/\?//g;

    return $term;
  }

  return undef;
}

sub lookup {
  my $self = shift;
  my $term = shift;

  if($term) {
    return $self->{facts}{$term};
  } else {
    return undef;
  }
}










