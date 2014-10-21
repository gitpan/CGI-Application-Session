package TestAppCGISimple;

use strict;

use CGI::Application;
use CGI::Application::Session;
@TestAppCGISimple::ISA = qw(CGI::Application);

sub cgiapp_init {
  my $self = shift;

  $self->session_config(CGI_SESSION_OPTIONS => [ "driver:File", $self->query, {Directory=>'t/'} ]);
}

sub setup {
    my $self = shift;

    $self->start_mode('test_mode');

    $self->run_modes(test_mode => 'test_mode' );
}

sub test_mode {
	my $self = shift;
  my $output = '';

  my $session = $self->session;

  $output .= $session->is_new ? "session created\n" : "session found\n";
  my $value = $session->param('value') || "";
  $output .= "value=$value\n";
  $output .= "id=".$session->id."\n";
  $output .= "query=".ref($self->query)."\n";

  $session->param('value' => 'test1');
  
  return $output;
}


1;
