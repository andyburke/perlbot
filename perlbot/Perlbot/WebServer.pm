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

  if(!$hostname) {
    debug("No hostname specified for WebServer!");
    return 0;
  }

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

    while (my $request = $connection->get_request) {
      if ($request->method eq 'GET') {

        my ($garbage, $dispatch, @args) = split('/', $request->uri());

        if($dispatch eq '') {
          my $response = "<html><head><title>Perlbot Web Interface</title></head><body><p><ul>";

          foreach my $link (keys(%{$self->{hooks}})) {
            if(defined($self->{hooks}{$link}[1])) {
              $response .= "<li><a href=\"/$link\">" . $self->{hooks}{$link}[1] . "</a>";
            } else {
              $response .= "<li><a href=\"/$link\">$link</a>";
            }
          }

          $response .= "</ul></body></html>";

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
            $connection->send_error(RC_NOT_FOUND);
          }
        } else {
          $connection->send_error(RC_NOT_FOUND);
        }
      }
    }
    $connection->close;

    exit;
  }
}

sub hook {
  my $self = shift;
  my $hook = shift;
  my $coderef = shift;
  my $description = shift;

  $self->{hooks}{$hook} = [$coderef, $description];
}


1;











