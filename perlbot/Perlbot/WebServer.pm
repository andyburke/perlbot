package Perlbot::WebServer;

use Perlbot::Utils;

use HTTP::Daemon;
use HTTP::Response;
use HTTP::Headers;
use HTTP::Status;

use XML::Simple;

sub new {
  my $class = shift;
  my $perlbot = shift;

  my $self = {
    _server => undef,
    perlbot => $perlbot,
    hooks => {}
  };

  bless $self, $class;
  return $self;
}

sub perlbot {
  my $self = shift;
  return $self->{perlbot};
}

sub start {
  my $self = shift;

  my $hostname = $self->perlbot->config->value(webserver => 'hostname');
  my $port = $self->perlbot->config->value(webserver => 'port');

  if(!$port) {
    $port = 9090;
  }

  $self->{_server} = HTTP::Daemon->new(LocalAddr => $hostname,
                                       LocalPort => $port);

  if (!$self->{_server}) {
    debug("Could not create WebServer http server: $!");
    return 0;
  }

  $self->perlbot->ircobject->addfh($self->{_server}, sub { $self->connection(shift) });
  
  return 1;
}

sub shutdown {
  my $self = shift;

  if($self->{_server}) {
    $self->perlbot->ircobject->removefh($self->{_server});
    $self->{_server}->close;
    $self->{_server} = undef;
  }
}

sub connection {
  my $self = shift;
  my $server = shift;

  my $pid;

  if (!defined($pid = fork)) {
    return;
  }

  if ($pid) {
    # parent

    $SIG{CHLD} = IGNORE;

  } else {
    # child

    $self->perlbot->ircconn->{_connected} = 0;
    
    my $connection = $server->accept();
    
    my $request = $connection->get_request();
    
    if ($request->method eq 'GET') {
      
      my ($garbage, $dispatch, @args) = split('/', $request->uri());
      
      if (!defined($dispatch) or $dispatch eq '') {
        my $response = "<html><head><title>Perlbot Web Interface</title></head><body><center><table width=50% border=1>";

        $response .= "<tr><td><table border=0 width=100%><tr><td><font size=+1>Perlbot Web Services</font></td><td align=right><font size=-1><a href=\"http://www.perlbot.org/\">perlbot v" . $Perlbot::VERSION . "</a></font></td></tr></table></td></tr>";

        $response .= "<tr><td><ul>";
        
        foreach my $link (keys(%{$self->{hooks}})) {
          if(defined($self->{hooks}{$link}[1])) {
            $response .= "<li><a href=\"/$link\">" . $self->{hooks}{$link}[1] . "</a>";
          } else {
            $response .= "<li><a href=\"/$link\">$link</a>";
          }
        }
        
        $response .= "</ul></td></tr></table><center></body></html>";
        
        $connection->send_response(HTTP::Response->new(RC_OK, status_message(RC_OK),
                                                     HTTP::Headers->new(Content_Type => 'text/html'),
                                                       $response));
      } elsif(exists($self->{hooks}{$dispatch})) {
        my $coderef = $self->{hooks}{$dispatch}[0];
        my $description = $self->{hooks}{$dispatch}[1];
        my ($contenttype, $content) = $coderef->(@args);
        
        if(defined($contenttype) && defined($content)) {
          $connection->send_response(HTTP::Response->new(RC_OK, status_message(RC_OK),
                                                       HTTP::Headers->new(Content_Type => $contenttype),
                                                         $content));
        } else {
          # undef contenttype or content means "return a 404"
          $connection->send_error(RC_NOT_FOUND);
        }
      } else {
        # nobody has hooked this path
        $connection->send_error(RC_NOT_FOUND);
      }
    }
    $connection->force_last_request;
    $connection->close;
    exit;
  }
}

sub hook {
  my $self = shift;
  my ($hook, $coderef, $description, $plugin) = @_;

  $self->{hooks}{$hook} = [$coderef, $description, $plugin];
}

# unhooks everything hooked by a given plugin
sub unhook_all {
  my $self = shift;
  my ($plugin) = @_;

  foreach my $hook (keys %{$self->{hooks}}) {
    if ($self->{hooks}{$hook}[2] eq $plugin) {
      delete $self->{hooks}{$hook};
    }
  }
}

sub num_hooks {
  my $self = shift;

  return scalar keys %{$self->{hooks}};
}


1;











