# oh my god this code is awful
#
# unless you have a desire to disconnect a lobe in response, read no further

package Perlbot::Plugin::Trivia;

use Perlbot::Plugin;
@ISA = qw(Perlbot::Plugin);

use strict;
use Time::HiRes qw(time);
use DB_File;
use String::Approx qw(amatch);

our $VERSION = '0.2.0';

sub init {
  my $self = shift;

  $self->want_fork(0);
  $self->want_msg(0);

  $self->{state} = 'idle';

  $self->{minquestionsanswered} = 25;

  $self->{question} = -1;

  $self->{questions} = {};

  $self->{playing} = {};

  open(TRIVIA, File::Spec->catfile($self->{directory}, 'trivia'));
  my $i = 0;
  while(my $q = <TRIVIA>) {
    chomp $q;
    $self->{questions}{$i} = $q;
    $i++;
  }
  close(TRIVIA);

  $self->{score} = {};
  $self->{answeredthisquestion} = {};
  $self->{answeredthisround} = {};

  tie %{$self->{correctlyanswered}},  'DB_File', File::Spec->catfile($self->{directory}, 'correctlyanswereddb'), O_CREAT|O_RDWR, 0640, $DB_HASH;
  tie %{$self->{totalanswered}},  'DB_File', File::Spec->catfile($self->{directory}, 'totalanswereddb'), O_CREAT|O_RDWR, 0640, $DB_HASH;
  
  $self->{percentageranks} = {};
  $self->{winsranks} = {};
  $self->{winstimespercentageranks} = {};
  $self->{percentagerank} = {};
  $self->{winsrank} = {};
  $self->{winstimespercentagerank} = {};

  $self->{askedtime} = 0;
  
  $self->{fastest} = {};
  tie %{$self->{fastestoverall}},  'DB_File', File::Spec->catfile($self->{directory}, 'fastestoveralldb'), O_CREAT|O_RDWR, 0640, $DB_HASH;


  $self->{curquestion} = 1;
  $self->{numquestions} = 0;
  $self->{answered} = 0;

  $self->hook('trivia', \&starttrivia);
  $self->hook('stoptrivia', \&stoptrivia);
  $self->hook('triviatop', \&triviatop);
  $self->hook('triviastats', \&triviastats);
  $self->hook('playing', \&playing);
  $self->hook('stopplaying', \&stopplaying);
  $self->hook(\&answer);

}

sub starttrivia {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  if($self->{state} ne 'idle') {
    $self->reply_error('A trivia game is already in progress!');
    return;
  }

  $self->{state} = 'playing';

  my ($numquestions) = $text =~ /(\d+)/;
  $numquestions ||= 15;

  $self->{numquestions} = $numquestions;
  $self->reply("Starting a new trivia game of $numquestions questions!");
  $self->reply("  To register to play in this game, type " . $self->perlbot->config->value(bot => 'commandprefix') . "playing");
  $self->reply("  To stop playing in this game, type " . $self->perlbot->config->value(bot => 'commandprefix') . "stopplaying");
  $self->reply("  Lines beginning with a '.' will not be counted as answers.");

  $self->perlbot->ircconn->schedule(10, sub { $self->askquestion() });
}

sub stoptrivia {
  my $self = shift;

  if($self->{state} ne 'idle') {
    $self->{state} = 'idle';
    $self->reply('Trivia stopped!');
    $self->endofgame();
  }

}

sub answer {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;

  if(!defined($self->{playing}{$event->nick()})) {
    return;
  }

  if(substr($text, 0, 1) eq '.' || substr($text, 0, 1) eq '!') {
    return;
  }

  my $nick;

  if($user) {
    $nick = $user->name();
  } else {
    $nick = $self->{lastnick};
  }

  if($self->{state} ne 'asked' || $self->{answered}) {
    return;
  }

  if(!defined($self->{answeredthisquestion}{$nick})) {
    if(!defined($self->{answeredthisround}{$nick})) {
      $self->{answeredthisround}{$nick} = 1;
    } else {
      $self->{answeredthisround}{$nick}++;
    }
  }
  $self->{answeredthisquestion}{$nick} = 1;
  
  my ($category, $question, $answer) = split(':::', $self->{questions}{$self->{question}});

  my $correct = 0;

  my $tmpanswer = $answer;
  my $tmptext = $text;

  $tmpanswer =~ s/(the|a)\s+//ig;
  $tmptext =~ s/(the|a)\s+//ig;
  
  my @answerwords = split(' ', $tmpanswer);
  my @guesswords = split(' ', $tmptext);
  
  if(length(@answerwords) != length(@guesswords)) {
    return;
  }
  
  my $numwords = @answerwords;
  print "numwords: $numwords\n";
  my $right = 0;
  my $i;
  for($i = 0; $i < $numwords; $i++) {
    if(defined($answerwords[$i]) && defined($guesswords[$i])) {
      print "comparing: $answerwords[$i] to guess: $guesswords[$i]\n";
      if(length($answerwords[$i]) < 6) {
        if(lc($answerwords[$i]) eq lc($guesswords[$i])) {
          $right++;
          print "  short and correct\n";
        } else {
          print "  short and incorrect\n";
        }
      } else {
        if(amatch(lc($answerwords[$i]), lc($guesswords[$i]))) {
          $right++;
          print "  long and correct\n";
        } else {
          print "  long and incorrect\n";
        }
      }
    }
  }

  if($right == $numwords) { $correct = 1; }

  if($correct) {
    my $timediff = sprintf("%0.2f", time() - $self->{askedtime});
    $self->{answered} = 1;
    $self->{state} = 'answered';
    $self->{score}{$nick}++;
    $self->{correctlyanswered}{$nick}++;
    if(!defined($self->{fastest}{$nick})) {
      $self->{fastest}{$nick} = $timediff;
    }
    if(!defined($self->{fastestoverall}{$nick})) {
      $self->{fastestoverall}{$nick} = $timediff;
    }
    
    my @percentageranks = $self->rankplayersbypercentage($self->getqualifyingplayers());
    my $oldpercentagerank = $self->{percentageranks}{$nick};
    
    my $percentagerank = 1;
    foreach my $name (@percentageranks) {
      $self->{percentageranks}{$name} = $percentagerank;
      $percentagerank++;
    }

    $percentagerank = $self->{percentageranks}{$nick};

    my @winsranks = $self->rankplayersbywins($self->getqualifyingplayers());
    my $oldwinsrank = $self->{winsranks}{$nick};
    
    my $winsrank = 1;
    foreach my $name (@winsranks) {
      $self->{winsranks}{$name} = $winsrank;
      $winsrank++;
    }

    $winsrank = $self->{winsranks}{$nick};

    my @timeranks = $self->rankplayersbytime($self->getqualifyingplayers());
    my $oldtimerank = $self->{timeranks}{$nick};
    
    my $timerank = 1;
    foreach my $name (@timeranks) {
      $self->{timeranks}{$name} = $timerank;
      $timerank++;
    }

    $timerank = $self->{timeranks}{$nick};

    $self->reply("The answer was: $answer");
    $self->reply("Winner: $nick  T:$timediff($self->{fastestoverall}{$nick}) S:" . $self->score($nick) . "% W:$self->{correctlyanswered}{$nick} TA:$self->{totalanswered}{$nick} %R:$percentagerank WR:$winsrank TR:$timerank");
    $self->reply("        This round: FT:$self->{fastest}{$nick} S:" . sprintf("%0.1f", 100 * ($self->{score}{$nick} / $self->{answeredthisround}{$nick})) . "% W:$self->{score}{$nick} A:$self->{answeredthisround}{$nick}");

    if($timediff < $self->{fastest}{$nick}) {
      $self->{fastest}{$nick} = $timediff;
    }
    if($timediff < $self->{fastestoverall}{$nick}) {
      $self->{fastestoverall}{$nick} = $timediff;
      $self->reply("That's a new speed record for $nick!");
    }

    if(defined($oldpercentagerank) && $percentagerank < $oldpercentagerank) {
      $self->reply("$nick has moved up in the percentage standings from $oldpercentagerank to $percentagerank!!");
    }
    if(defined($oldpercentagerank) && $percentagerank > $oldpercentagerank) {
      $self->reply("Sad day, $nick has dropped from $oldpercentagerank to $percentagerank in the percentage standings...");
    }

    if(defined($oldwinsrank) && $winsrank < $winsrank) {
      $self->reply("$nick has moved up in the overall wins standings from $oldwinsrank to $winsrank!!");
    }
    if(defined($oldwinsrank) && $winsrank > $oldwinsrank) {
      $self->reply("Sad day, $nick has dropped from $oldwinsrank to $winsrank in the overall wins standings...");
    }

    if(defined($oldtimerank) && $timerank < $timerank) {
      $self->reply("$nick has moved up in the fastest time standings from $oldtimerank to $timerank!!");
    }
    if(defined($oldtimerank) && $timerank > $oldtimerank) {
      $self->reply("Sad day, $nick has dropped from $oldtimerank to $timerank in the fastest time standings...");
    }
    
    
    $self->{curquestion}++;
    $self->perlbot->ircconn->schedule(10, sub { $self->askquestion() });    

    foreach my $person (keys(%{$self->{answeredthisquestion}})) {
      $self->{totalanswered}{$person}++;
      delete $self->{answeredthisquestion}{$person};
    }
  }
}

sub askquestion {
  my $self = shift;

  if($self->{state} ne 'playing' and $self->{state} ne 'answered') {
    return;
  }
  
  if($self->{curquestion} <= $self->{numquestions}) {

    $self->{question} = rand(100000) % keys(%{$self->{questions}});
    $self->{state} = 'asked';
    
    my ($category, $question, $answer) = split(':::', $self->{questions}{$self->{question}});
    my $curquestion = $self->{curquestion};

    $self->{answered} = 0;
    $self->reply("${curquestion}. [${category}] $question");
    $self->{askedtime} = time();
    $self->perlbot->ircconn->schedule(10, sub { $self->hint(eval "$curquestion") });
    $self->perlbot->ircconn->schedule(30, sub { $self->notanswered(eval "$curquestion") });
  } else {
    $self->reply("Game over.");
    $self->endofgame();
  }
}

sub hint {
  my $self = shift;
  my $question = shift;

  if($self->{state} ne 'asked' || $self->{curquestion} != $question) {
    return;
  }

  my ($category, $q, $a) = split(':::', $self->{questions}{$self->{question}});

  my $blackout;
  if(length($a) > 3) {
    $blackout = (length($a) / 2) + (rand(1000) % (length($a)/4)) - 1;
  } else {
    $blackout = length($a);
  }

  my $hint;
  if(int(rand(2)) == 1) {
    substr($a, 0, (length($a) - $blackout)) =~ tr[ A-Za-z0-9][ #];
  } else {
    substr($a, (length($a) - $blackout)) =~ tr[ A-Za-z0-9][ #];
  }

  $self->reply("Hint: $a");
}

sub notanswered {
  my $self = shift;
  my $question = shift;

  if($self->{state} ne 'asked' || $self->{curquestion} != $question) {
    return;
  }

  my ($category, $questiontext, $answer) = split(':::', $self->{questions}{$self->{question}});

  $self->reply("The answer was: $answer");
  $self->{state} = 'playing';
  $self->perlbot->ircconn->schedule(10, sub { $self->askquestion() });
  $self->{curquestion}++;

  foreach my $person (keys(%{$self->{answeredthisquestion}})) {
    $self->{totalanswered}{$person}++;
    delete $self->{answeredthisquestion}{$person};
  }

}

sub endofgame {
  my $self = shift;
  my $winner;
  my $winnerscore = -1;

  foreach my $nick (keys(%{$self->{score}})) {
    if($self->{answeredthisround}{$nick} > 0) {
      if(($self->{score}{$nick} / $self->{answeredthisround}{$nick}) > $winnerscore) {
        $winner = $nick;
        $winnerscore = $self->{score}{$nick} / $self->{answeredthisround}{$nick};
      }
    }
    delete $self->{score}{$nick}; # reset wins
  }

  if($winnerscore == -1) {
    return;
  }

  my $fastest = $self->{fastest}{$winner};

  $self->reply("Trivia Winner for this round is: $winner with a score of " . sprintf("%0.1f%", 100 * $winnerscore) . " and a fastest time of $fastest!");

  foreach my $nick (keys(%{$self->{playing}})) {
    delete $self->{playing}{$nick};
  }

  foreach my $nick (keys(%{$self->{answeredthisround}})) {
    delete $self->{answeredthisround}{$nick};
  }

  $self->{curquestion} = 1;
  $self->{state} = 'idle';

}

sub triviatop {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my @response;


  my ($num) = $text =~ /(\d+)/;
  $num ||= 5;

  if($num > 10) { $num = 10; }

  $self->reply("Top $num trivia players are: (you must answer at least $self->{minquestionsanswered} questions to be ranked!)");
  my $headers = sprintf("%-18s", '% Rankings:') . sprintf("%-18s", 'Wins Rankings:') . sprintf("%-18s", 'Time Rankings:') . sprintf("%-18s", 'W x % Rankings:');
  $self->reply($headers);

  my @ranks = $self->rankplayersbypercentage($self->getqualifyingplayers());
  my $rank = 1;
  foreach my $name (@ranks) {
    push(@response, sprintf("%-18s", "$rank " . sprintf("%-8s", $name) . "(" . $self->score($name) . "%)"));
    $rank++;
    if($rank >= $num + 1) { last; }
  }

  @ranks = $self->rankplayersbywins($self->getqualifyingplayers());
  $rank = 1;
  foreach my $name (@ranks) {
    if($response[$rank - 1]) {
      $response[$rank - 1] = $response[$rank - 1] . sprintf("%-18s", "$rank " . sprintf("%-8s", $name) . "(" . $self->{correctlyanswered}{$name} . ")");
      $rank++;
      if($rank >= $num + 1) { last; }
    }
  }

  @ranks = $self->rankplayersbytime($self->getqualifyingplayers());
  $rank = 1;
  foreach my $name (@ranks) {
    if($response[$rank - 1]) {
      $response[$rank - 1] = $response[$rank - 1] . sprintf("%-18s", "$rank " . sprintf("%-8s", $name) . "(" . $self->{fastestoverall}{$name} . ")");
      $rank++;
      if($rank >= $num + 1) { last; }
    }
  }

  @ranks = $self->rankplayersbywinstimespercentage($self->getqualifyingplayers());
  $rank = 1;
  foreach my $name (@ranks) {
    if($response[$rank - 1]) {
      $response[$rank - 1] = $response[$rank - 1] . sprintf("%-18s", "$rank " . sprintf("%-8s", $name) . "(" . sprintf("%d", ($self->{correctlyanswered}{$name} * $self->score($name))/100) . ")");
      $rank++;
      if($rank >= $num + 1) { last; }
    }
  }

  $self->reply(@response);

}

sub triviastats {
  my $self = shift;
  my $user = shift;
  my $text = shift;

  my $nick = $text;

  if(!defined($nick)) {
    $self->reply_error('You must specify a nick to get stats on!');
    return;
  }

  if($self->{totalanswered}{$nick}) {

    my @percentageranks = $self->rankplayersbypercentage($self->getallplayers());
    my $percentagerank = 1;
    foreach my $name (@percentageranks) {
      $self->{percentageranks}{$name} = $percentagerank;
      $percentagerank++;
    }

    $percentagerank = $self->{percentageranks}{$nick};

    my @winsranks = $self->rankplayersbywins($self->getallplayers());    
    my $winsrank = 1;
    foreach my $name (@winsranks) {
      $self->{winsranks}{$name} = $winsrank;
      $winsrank++;
    }

    $winsrank = $self->{winsranks}{$nick};

    my @timeranks = $self->rankplayersbytime($self->getallplayers());
    my $timerank = 1;
    foreach my $name (@timeranks) {
      $self->{timeranks}{$name} = $timerank;
      $timerank++;
    }

    $timerank = $self->{timeranks}{$nick};

    my @wpranks = $self->rankplayersbywinstimespercentage($self->getallplayers());
    my $wprank = 1;
    foreach my $name (@wpranks) {
      $self->{winstimespercentageranks}{$name} = $wprank;
      $wprank++;
    }

    $wprank = $self->{winstimespercentageranks}{$nick};

    $self->reply("$nick: %R:$percentagerank  WR:$winsrank  TR:$timerank  W%R:$wprank  W:$self->{correctlyanswered}{$nick}  TA:$self->{totalanswered}{$nick}  S:" . $self->score($nick) . "%  FT: $self->{fastestoverall}{$nick}");
  }
}

sub triviahelp {
  my $self = shift;

  $self->reply("You must register to play in each round of trivia.");
  $self->reply("During a round you've registered for, your attempts at answering are recorded.");
  $self->reply("Your overall score is: correctly answered / total answered");
  $self->reply("Once you have submitted an answer to a question, additional submissions do not count as attempts");
  $self->reply("Once a question has been answered correctly, no submissions are counted.");
}

sub playing {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;
  my $nick = $event->nick();

  $self->{playing}{$nick} = 1;
}

sub stopplaying {
  my $self = shift;
  my $user = shift;
  my $text = shift;
  my $event = shift;
  my $nick = $event->nick();

  delete $self->{playing}{$nick};
}

sub rankplayersbypercentage {
  my $self = shift;
  my @players = @_;

  my @ranks = sort { $self->score($b) <=> $self->score($a) } @players;

  return @ranks;
}

sub rankplayersbywins {
  my $self = shift;
  my @players = @_;

  my @ranks = sort { $self->{correctlyanswered}{$b} <=> $self->{correctlyanswered}{$a} }
                   @players;

  return @ranks;
}

sub rankplayersbytime {
  my $self = shift;
  my @players = @_;

  my @ranks = sort { $self->{fastestoverall}{$a} <=> $self->{fastestoverall}{$b} }
                   @players;

  return @ranks;
}

sub rankplayersbywinstimespercentage {
  my $self = shift;
  my @players = @_;

  my @ranks = sort { $self->score($b)*$self->{correctlyanswered}{$b} <=>
                     $self->score($a)*$self->{correctlyanswered}{$a} }
                   @players;

  return @ranks;
}

sub getqualifyingplayers {
  my $self = shift;

  my @players;

  foreach my $player (keys(%{$self->{totalanswered}})) {
    if($self->{totalanswered}{$player} >= $self->{minquestionsanswered}) {
      push(@players, $player);
    }
  }

  return @players;
}

sub getallplayers {
  my $self = shift;

  return keys(%{$self->{totalanswered}});
}

sub score {
  my $self = shift;
  my $name = shift;

  return sprintf("%0.1f", 100 * ($self->{correctlyanswered}{$name} / $self->{totalanswered}{$name}));
}

1;
