# oh my god this code is awful
#
# unless you have a desire to disconnect a lobe in response, read no further

package Perlbot::Plugin::Trivia;

use strict;
use Perlbot::Plugin;
use base qw(Perlbot::Plugin);
use fields qw(state minquestionsanswered gameid question questions playing score answeredthisquestion answeredthisround correctlyanswered totalanswered percentageranks winsranks performanceranks timeranks percentagerank winsrank performancerank timerank askedtime fastest fastestoverall beaten beatenoverall performance performanceoverall requestedhintnum lastrequestedhinttime initialhintgiven curquestion numquestions answered);

use Time::HiRes qw(time);
use DB_File;
use String::Approx qw(amatch);
use XML::Simple;

our $VERSION = '0.2.0';

sub init {
  my $self = shift;

  $self->want_fork(0);
  $self->want_msg(0);

  $self->{state} = 'idle';

  $self->{minquestionsanswered} = 25;

  $self->{gameid} = '';

  $self->{question} = -1;

  $self->{questions} = {};

  $self->{playing} = {};

  $self->{questions} = XMLin(File::Spec->catfile($self->{directory}, 'trivia.xml'))->{question};

  $self->{score} = {};
  $self->{answeredthisquestion} = {};
  $self->{answeredthisround} = {};

  tie %{$self->{correctlyanswered}},  'DB_File', File::Spec->catfile($self->{directory}, 'correctlyanswereddb'), O_CREAT|O_RDWR, 0640, $DB_HASH;
  tie %{$self->{totalanswered}},  'DB_File', File::Spec->catfile($self->{directory}, 'totalanswereddb'), O_CREAT|O_RDWR, 0640, $DB_HASH;
  
  $self->{percentageranks} = {};
  $self->{winsranks} = {};
  $self->{performanceranks} = {};

  $self->{percentagerank} = {};
  $self->{winsrank} = {};
  $self->{performancerank} = {};

  $self->{askedtime} = 0;
  
  $self->{fastest} = {};
  tie %{$self->{fastestoverall}},  'DB_File', File::Spec->catfile($self->{directory}, 'fastestoveralldb'), O_CREAT|O_RDWR, 0640, $DB_HASH;

  $self->{beaten} = {};
  tie %{$self->{beatenoverall}},  'DB_File', File::Spec->catfile($self->{directory}, 'beatenoveralldb'), O_CREAT|O_RDWR, 0640, $DB_HASH;

  $self->{performance} = {};
  tie %{$self->{performanceoverall}},  'DB_File', File::Spec->catfile($self->{directory}, 'performanceoveralldb'), O_CREAT|O_RDWR, 0640, $DB_HASH;


  $self->{requestedhintnum} = 0;
  $self->{lastrequestedhinttime} = 0;
  $self->{initialhintgiven} = 0;
  $self->{curquestion} = 1;
  $self->{numquestions} = 0;
  $self->{answered} = 0;

  $self->hook('trivia', \&starttrivia);
  $self->hook('stoptrivia', \&stoptrivia);
  $self->hook('triviatop', \&triviatop);
  $self->hook('triviastats', \&triviastats);
  $self->hook('playing', \&playing);
  $self->hook('stopplaying', \&stopplaying);
  $self->hook('notplaying', \&stopplaying);
  $self->hook('hint', \&requestedhint);
  $self->hook(\&answer);

  $self->hook_web('triviastats', \&webtriviastats, 'Trivia Statistics');

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
  $self->{gameid} = time();

  my ($numquestions) = $text =~ /(\d+)/;
  $numquestions ||= 15;

  $self->{numquestions} = $numquestions;
  $self->reply("Starting a new trivia game of $numquestions questions!");
  $self->reply("  To register to play in this game, type " . $self->perlbot->config->get(bot => 'commandprefix') . "playing");
  $self->reply("  To stop playing in this game, type " . $self->perlbot->config->get(bot => 'commandprefix') . "stopplaying");
  $self->reply("  Lines beginning with a '.' will not be counted as answers.");

  srand();

  $self->perlbot->schedule(10, sub { $self->askquestion() });
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
    if(!defined($self->{answeredthisround}{$nick}) || $self->{answeredthisround}{$nick} <= 0) {
      $self->{answeredthisround}{$nick} = 1;
    } else {
      $self->{answeredthisround}{$nick}++;
    }
  }
  $self->{answeredthisquestion}{$nick} = 1;

  my $correct = 0;

  my $answer = $self->{questions}[$self->{question}]{answer};
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
  my $right = 0;
  my $i;
  for($i = 0; $i < $numwords; $i++) {
    if(defined($answerwords[$i]) && defined($guesswords[$i])) {
      if(length($answerwords[$i]) < 6) {
        if(lc($answerwords[$i]) eq lc($guesswords[$i])) {
          $right++;
        }
      } else {
        if(amatch(lc($answerwords[$i]), lc($guesswords[$i]))) {
          $right++;
        }
      }
    }
  }

  if($right == $numwords) { $correct = 1; }

  if($correct) {
    my $numanswerers = keys(%{$self->{playing}});
    my $keepstats = 0;
    my $speedrecord = 0;
    if($numanswerers > 1) { $keepstats = 1; }
    my $timediff = sprintf("%0.2f", time() - $self->{askedtime});
    $self->{answered} = 1;
    $self->{state} = 'answered';
    $self->{score}{$nick}++;
    $self->{requestedhintnum} = 0;
    $self->{lastrequestedhinttime} = 0;
    $self->{initialhintgiven} = 0;

    foreach my $person (keys(%{$self->{answeredthisquestion}})) {
      if($keepstats) { $self->{totalanswered}{$person}++; }
      delete $self->{answeredthisquestion}{$person};
    }

    if($timediff < $self->{fastest}{$nick}) {
      $self->{fastest}{$nick} = $timediff;
    }
    if($timediff < $self->{fastestoverall}{$nick} && $keepstats) {
      $self->{fastestoverall}{$nick} = $timediff;
      $speedrecord = 1;
    }

    if($keepstats) { 
      $self->{correctlyanswered}{$nick}++;
      $self->{beatenoverall}{$nick} = $self->{beatenoverall}{$nick} + $numanswerers - 1;
      $self->{performanceoverall}{$nick} = $self->{beatenoverall}{$nick} / $self->{totalanswered}{$nick};
    }

    if(!defined($self->{fastest}{$nick})) {
      $self->{fastest}{$nick} = $timediff;
    }
    if(!defined($self->{fastestoverall}{$nick}) && $keepstats) {
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

    if(!defined($self->{performanceoverall}{$nick})) {
      $self->{performanceoverall}{$nick} = 0;
    }

    my @perfranks = $self->rankplayersbyperformance($self->getqualifyingplayers());
    my $oldperfrank = $self->{performanceranks}{$nick};
    
    my $perfrank = 1;
    foreach my $name (@perfranks) {
      $self->{performanceranks}{$name} = $perfrank;
      $perfrank++;
    }

    $perfrank = $self->{performanceranks}{$nick};

    $self->reply("The answer was: $answer");
    $self->reply("Winner: $nick  T:$timediff($self->{fastestoverall}{$nick}) S:" . $self->score($nick) . "% W:$self->{correctlyanswered}{$nick} TA:$self->{totalanswered}{$nick} %R:$percentagerank WR:$winsrank TR:$timerank PR:$perfrank");
    if($self->{answeredthisround}{$nick} <= 0) { $self->{answeredthisround}{$nick} = 1; }
    $self->reply("        This round: FT:$self->{fastest}{$nick} S:" . sprintf("%0.1f", 100 * ($self->{score}{$nick} / $self->{answeredthisround}{$nick})) . "% W:$self->{score}{$nick} A:$self->{answeredthisround}{$nick}");

    if($speedrecord) {
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

    if(defined($oldtimerank) && $timerank < $oldtimerank) {
      $self->reply("$nick has moved up in the fastest time standings from $oldtimerank to $timerank!!");
    }
    if(defined($oldtimerank) && $timerank > $oldtimerank) {
      $self->reply("Sad day, $nick has dropped from $oldtimerank to $timerank in the fastest time standings...");
    }

    if(defined($oldperfrank) && $perfrank < $oldperfrank) {
      $self->reply("$nick has moved up in the performance standings from $oldperfrank to $perfrank!!");
    }
    if(defined($oldperfrank) && $perfrank > $oldperfrank) {
      $self->reply("Sad day, $nick has dropped from $oldperfrank to $perfrank in the performance standings...");
    }
    
    
    $self->{curquestion}++;
    $self->perlbot->schedule(10, sub { $self->askquestion() });    

    foreach my $person (keys(%{$self->{answeredthisquestion}})) {
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

    $self->{question} = rand(100000000) % scalar(@{$self->{questions}});
    $self->{state} = 'asked';
    
    my $curquestion = $self->{curquestion};

    $self->{answered} = 0;
    $self->reply("${curquestion}. [" . $self->{questions}[$self->{question}]{category} . "] " . $self->{questions}[$self->{question}]{text});
    $self->{askedtime} = time();
    $self->perlbot->schedule(10, sub { $self->hint(eval "$curquestion") });
    $self->perlbot->schedule(30, sub { $self->notanswered(eval "$curquestion") });
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

  my $a = $self->{questions}[$self->{question}]{answer};

  if(length($a) > 4) {
    my $blackout;
    $blackout = (length($a) / 2) + (rand(1000) % (length($a)/4)) - 1;
    if(int(rand(2)) == 1) {
      substr($a, 0, (length($a) - $blackout)) =~ tr[ A-Za-z0-9][ #];
    } else {
      substr($a, (length($a) - $blackout)) =~ tr[ A-Za-z0-9][ #];
    }
  } else {
    $a =~ tr[ A-Za-z0-9][ #];
  }

  $self->reply("Hint: $a");
  $self->{initialhintgiven} = 1;
}

sub requestedhint {
  my $self = shift;

  if($self->{state} ne 'asked' || !$self->{initialhintgiven}) {
    return;
  }

  if(time - $self->{lastrequestedhinttime} < 5) {
    return;
  }

  if(defined($self->{questions}[$self->{question}]{hint}[$self->{requestedhintnum}])) {
    $self->reply("Hint: " . $self->{questions}[$self->{question}]{hint}[$self->{requestedhintnum}]);
  }
  $self->{requestedhintnum}++;
  $self->{lastrequestedhinttime} = time();
}

sub notanswered {
  my $self = shift;
  my $question = shift;
  my $numanswerers = keys(%{$self->{playing}});
  my $keepstats = 0;
  if($numanswerers > 1) { $keepstats = 1; }

  if($self->{state} ne 'asked' || $self->{curquestion} != $question) {
    return;
  }

  $self->reply("The answer was: " . $self->{questions}[$self->{question}]{answer});
  $self->{state} = 'playing';
  $self->perlbot->schedule(10, sub { $self->askquestion() });
  $self->{curquestion}++;

  foreach my $person (keys(%{$self->{answeredthisquestion}})) {
    if($keepstats) { $self->{totalanswered}{$person}++; }
    delete $self->{answeredthisquestion}{$person};
  }

  $self->{requestedhintnum} = 0;
  $self->{lastrequestedhinttime} = 0;
  $self->{initialhintgiven} = 0;

}

sub endofgame {
  my $self = shift;
  my $winner;
  my $winnerscore = -1;

  foreach my $nick (keys(%{$self->{score}})) {
    if($self->{answeredthisround}{$nick} > 0) {
      if($self->{score}{$nick} > $winnerscore) {
        $winner = $nick;
        $winnerscore = $self->{score}{$nick};
      }
    }
    delete $self->{score}{$nick}; # reset wins
  }

  if($winnerscore == -1) {
    $self->{curquestion} = 1;
    $self->{state} = 'idle';
    return;
  }

  my $fastest = $self->{fastest}{$winner};

  $self->reply("Trivia Winner for this round is: $winner with $winnerscore wins and a fastest time of $fastest!");

  foreach my $nick (keys(%{$self->{playing}})) {
    delete $self->{playing}{$nick};
  }

  foreach my $nick (keys(%{$self->{fastest}})) {
    delete $self->{fastest}{$nick};
  }

  foreach my $nick (keys(%{$self->{answeredthisround}})) {
    delete $self->{answeredthisround}{$nick};
  }

  $self->{requestedhintnum} = 0;
  $self->{lastrequestedhinttime} = 0;
  $self->{initialhintgiven} = 0;

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

  if($num > 20) { $num = 20; }

  push(@response, "Top $num trivia players are: (you must answer at least $self->{minquestionsanswered} questions to be ranked!)");
  my $headers = sprintf("%-19s", '% Rankings:') . sprintf("%-19s", 'Wins Rankings:') . sprintf("%-19s", 'Time Rankings:') . sprintf("%-19s", 'Performance Rankings:');
  push(@response, $headers);

  my @ranks = $self->rankplayersbypercentage($self->getqualifyingplayers());
  my $rank = 1;
  foreach my $name (@ranks) {
    push(@response, sprintf("%-19s", sprintf("%-3s", $rank) . sprintf("%-8s", substr($name, 0, 8)) . "(" . $self->score($name) . "%)"));
    $rank++;
    if($rank >= $num + 1) { last; }
  }

  @ranks = $self->rankplayersbywins($self->getqualifyingplayers());
  $rank = 1;
  foreach my $name (@ranks) {
    if($response[$rank + 1]) {
      $response[$rank + 1] = $response[$rank + 1] . sprintf("%-19s", sprintf("%-3s", $rank) . sprintf("%-8s", substr($name, 0, 8)) . "(" . $self->{correctlyanswered}{$name} . ")");
      $rank++;
      if($rank >= $num + 1) { last; }
    }
  }

  @ranks = $self->rankplayersbytime($self->getqualifyingplayers());
  $rank = 1;
  foreach my $name (@ranks) {
    if($response[$rank + 1]) {
      $response[$rank + 1] = $response[$rank + 1] . sprintf("%-19s", sprintf("%-3s", $rank) . sprintf("%-8s", substr($name, 0, 8)) . "(" . $self->{fastestoverall}{$name} . ")");
      $rank++;
      if($rank >= $num + 1) { last; }
    }
  }

  @ranks = $self->rankplayersbyperformance($self->getqualifyingplayers());
  $rank = 1;
  foreach my $name (@ranks) {
    if($response[$rank + 1]) {
      $response[$rank + 1] = $response[$rank + 1] . sprintf("%-19s", sprintf("%-3s", $rank) . sprintf("%-8s", substr($name, 0, 8)) . "(" . sprintf("%0.2f", $self->{performanceoverall}{$name}) . ")");
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

    my @percentageranks = $self->rankplayersbypercentage($self->getqualifyingplayers());
    my $percentagerank = 1;
    foreach my $name (@percentageranks) {
      $self->{percentageranks}{$name} = $percentagerank;
      $percentagerank++;
    }

    $percentagerank = $self->{percentageranks}{$nick};
    $percentagerank ||= 'n/a';

    my @winsranks = $self->rankplayersbywins($self->getqualifyingplayers());
    my $winsrank = 1;
    foreach my $name (@winsranks) {
      $self->{winsranks}{$name} = $winsrank;
      $winsrank++;
    }

    $winsrank = $self->{winsranks}{$nick};
    $winsrank ||= 'n/a';

    my @timeranks = $self->rankplayersbytime($self->getqualifyingplayers());
    my $timerank = 1;
    foreach my $name (@timeranks) {
      $self->{timeranks}{$name} = $timerank;
      $timerank++;
    }

    $timerank = $self->{timeranks}{$nick};
    $timerank ||= 'n/a';

    my @perfranks = $self->rankplayersbyperformance($self->getqualifyingplayers());
    my $perfrank = 1;
    foreach my $name (@perfranks) {
      $self->{performanceranks}{$name} = $perfrank;
      $perfrank++;
    }

    $perfrank = $self->{performanceranks}{$nick};
    $perfrank ||= 'n/a';

    $self->reply("$nick: %R:$percentagerank  WR:$winsrank  TR:$timerank  PR:$perfrank  Avg:" . ($percentagerank + $winsrank + $timerank + $perfrank) / 4 . "  W:$self->{correctlyanswered}{$nick}  TA:$self->{totalanswered}{$nick}  S:" . $self->score($nick) . "%  FT: $self->{fastestoverall}{$nick}");
  }
}

sub webtriviastats {
  my $self = shift;
  my @args = @_;

  my $response = "<html><head><title>Perlbot Trivia Stats</title></head><body>";

  $response .= "<p><center><font size=+1>Top 20 Trivia Players</font></center>";

  $response .= "<p><table width=100%>";

  $response .= "<tr><td><b>Rank</b></td><td><b>% Rankings</b></td><td><b>Wins Rankings</b></td><td><b>Time Rankings</b></td><td><b>Performance Rankings</b></td></tr>";

  my @percranks = $self->rankplayersbypercentage($self->getqualifyingplayers());
  my @winsranks = $self->rankplayersbywins($self->getqualifyingplayers());
  my @timeranks = $self->rankplayersbytime($self->getqualifyingplayers());
  my @perfranks = $self->rankplayersbyperformance($self->getqualifyingplayers());

  if(@percranks && @winsranks && @timeranks && @perfranks) {

    for(my $rank = 0; $rank < 20; $rank++) {
      if(!defined($percranks[$rank])) { last; }
      my $numerical_rank = $rank + 1;
      $response .= "<tr><td>$numerical_rank</td>";
      $response .= "<td>" . $percranks[$rank] . " (" . $self->score($percranks[$rank]) . "%)</td>";
      $response .= "<td>" . $winsranks[$rank] . " (" . $self->{correctlyanswered}{$winsranks[$rank]} . ")</td>";
      $response .= "<td>" . $timeranks[$rank] . " (" . $self->{fastestoverall}{$timeranks[$rank]} . ")</td>";
      $response .= "<td>" . $perfranks[$rank] . " (" . sprintf("%0.2f", $self->{performanceoverall}{$perfranks[$rank]}) . ")</td>";
      $response .= "</tr>";
    }
  } else {
    $response .= "<tr><td colspan=5 align=middle><b>No current trivia rankings!</b></td></tr>";
  }

  $response .= "</table></body>";
  
  return ('text/html', $response);

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

sub rankplayersbyperformance {
  my $self = shift;
  my @players = @_;

  my @ranks = sort { $self->{performanceoverall}{$b} <=> $self->{performanceoverall}{$a} }
                   @players;

  return @ranks;
}

sub getqualifyingplayers {
  my $self = shift;

  my @players;

  foreach my $player (keys(%{$self->{totalanswered}})) {
    if($self->{totalanswered}{$player} >= $self->{minquestionsanswered} &&
       defined($self->{correctlyanswered}{$player}) &&
       defined($self->{fastestoverall}{$player}) &&
       defined($self->score($player))) {
      if(!defined($self->{performanceoverall}{$player})) {
        $self->{performanceoverall}{$player} = 0;
      }
      push(@players, $player);
    }
  }

  return @players;
}

sub getallplayers {
  my $self = shift;

  my @players;

  foreach my $player (keys(%{$self->{totalanswered}})) {
    if(defined($self->{correctlyanswered}{$player}) &&
       defined($self->{fastestoverall}{$player}) &&
       defined($self->score($player))) {
      push(@players, $player);
    }
  }

  return @players;

}

sub score {
  my $self = shift;
  my $name = shift;

  if(!$self->{totalanswered}{$name}) {
    return 0;
  }

  return sprintf("%0.1f", 100 * ($self->{correctlyanswered}{$name} / $self->{totalanswered}{$name}));
}

1;
