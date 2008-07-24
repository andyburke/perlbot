package HTMLPlog;

use strict;

sub makehtml {

  my $filename = shift;
  
  open FILE, $filename;
  my @lines = <FILE>;
  close FILE;
  
  print <<END;
  <HTML>
    <HEAD>
      <TITLE>Perlbot Log</TITLE>
    </HEAD>

    <BODY BGCOLOR=#FFFFFF TEXT=#000000>
END
			  
  foreach (@lines) {
    s/</\&lt\;/g;
    s/>/\&gt\;/g;
    s/(\&lt\;.*?\&gt\;)/<b>$1<\/b>/;
    s|^(\d+:\d+:\d+) \* (\w+) (.*)|$1 * <b>$2</b> $3|;
    s/^(\d+:\d+:\d+\s)(.*? joined \#.*?$)/$1<FONT COLOR=\"BLUE\">$2<\/FONT>/;
    s/^(\d+:\d+:\d+\s)(.*? left \#.*?$)/$1<FONT COLOR=\"BLUE\">$2<\/FONT>/;
    s/^(\d+:\d+:\d+\s)(\[.*?\])/$1<FONT COLOR\=\"RED\">$2<\/FONT>/;
    s/(\d+\:\d+:\d+)/<A NAME=\"$1\">$1<\/A>/;
    print "      <TT>$_</TT><BR>";
  }
  
  print <<END;
    </BODY>
  </HTML>
END

}

1;
