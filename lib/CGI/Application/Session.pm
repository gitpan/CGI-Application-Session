package CGI::Application::Session;

use CGI::Session;
use CGI::Application 3.21;

use strict;
use vars qw($VERSION);

$VERSION = '0.02';

package CGI::Application;

sub session {
    my $self = shift;

    if (!$self->{__SESSION}) {
        # define the config hash if it doesn't exist to save some checks later
        $self->{__SESSION_CONFIG} = {} unless $self->{__SESSION_CONFIG};

        # create CGI::Session object
        if ($self->{__SESSION_CONFIG}->{CGI_SESSION_OPTIONS}) {
            # use the parameters the user supplied
            $self->{__SESSION} = CGI::Session->new(@{ $self->{__SESSION_CONFIG}->{CGI_SESSION_OPTIONS} });
        } else {
            # use some sane defaults
            $self->{__SESSION} = CGI::Session->new('driver:File', $self->query, {Directory=>'/tmp'});
        }

        # add the cookie to the outgoing headers
        #  only add the cookie if it doesn't exist,
        #  or if the session ID doesn't match what is in the
        #  current cookie
        if (!defined $self->{__SESSION_CONFIG}->{SEND_COOKIE} || $self->{__SESSION_CONFIG}->{SEND_COOKIE}) {
            my $cid = $self->query->cookie(CGI::Session->name);
            if (!$cid || $cid ne $self->{__SESSION}->id) {
                $self->session_cookie;
            }
        }
    }

    return $self->{__SESSION};
}

sub session_config {
    my $self = shift;

    if (@_) {
      die "Calling session_config after the session has already been created" if (defined $self->{__SESSION});
      my $props;
      if (ref($_[0]) eq 'HASH') {
          my $rthash = %{$_[0]};
          $props = $self->_cap_hash($_[0]);
      } else {
          $props = $self->_cap_hash({ @_ });
      }

      # Check for CGI_SESSION_OPTIONS
      if ($props->{CGI_SESSION_OPTIONS}) {
        die "session_config error:  parameter CGI_SESSION_OPTIONS is not an array reference" if ref $props->{CGI_SESSION_OPTIONS} ne 'ARRAY';
        $self->{__SESSION_CONFIG}->{CGI_SESSION_OPTIONS} = delete $props->{CGI_SESSION_OPTIONS};
      }

      # Check for COOKIE_PARAMS
      if ($props->{COOKIE_PARAMS}) {
        die "session_config error:  parameter COOKIE_PARAMS is not a hash reference" if ref $props->{COOKIE_PARAMS} ne 'HASH';
        $self->{__SESSION_CONFIG}->{COOKIE_PARAMS} = delete $props->{COOKIE_PARAMS};
      }

      # Check for SEND_COOKIE
      if (defined $props->{SEND_COOKIE}) {
        $self->{__SESSION_CONFIG}->{SEND_COOKIE} = (delete $props->{SEND_COOKIE}) ? 1 : 0;
      }

      # If there are still entries left in $props then they are invalid
      die "Invalid option(s) (".join(', ', keys %$props).") passed to session_config" if %$props;
    }

    $self->{__SESSION_CONFIG};
}

sub session_cookie {
    my $self = shift;
    my %options = @_;

    # merge in any parameters set by config_session
    if ($self->{__SESSION_CONFIG}->{COOKIE_PARAMS}) {
      %options = (%{ $self->{__SESSION_CONFIG}->{COOKIE_PARAMS} }, %options);
    }

    $options{'-name'}  ||= CGI::Session->name;
    $options{'-value'} ||= $self->session->id;
    $options{'-path'}  ||= '/';
    my $cookie = $self->query->cookie(%options);
    $self->header_add(-cookie => [$cookie]);
}

1;
__END__

=head1 NAME

CGI::Application::Session - Add CGI::Session support to CGI::Application


=head1 SYNOPSIS

 use CGI::Application::Session;

 my $language = $self->session->param('language');

=head1 DESCRIPTION

CGI::Application::Session seamlessly adds session support to your L<CGI::Application>
modules by providing a L<CGI::Session> object that is accessible from anywhere in
the application.

Lazy loading is used to prevent expensive file system or database calls from being made if
the session is not needed during this request.  In other words, the Session object is not
created until it is actually needed.  Also, the Session object will act as a singleton
by always returning the same Session object for the duration of the request.

This module aims to be as simple and non obtrusive as possible.  By not requiring
any changes to the inheritance tree of your modules, it can be easily added to
existing applications.  Think of it as a plugin module that adds a couple of
new methods directly into the CGI::Application namespace simply by loading the module.  

=head1 METHODS

=head2 session

This method will return the current L<CGI::Session> object.  The L<CGI::Session> object is created on
the first call to this method, and any subsequent calls will return the same object.  This effectively
creates a singleton session object for the duration of the request.  L<CGI::Session> will look for a cookie
or param containing the session ID, and create a new session if none is found.  If C<session_config>
has not been called before the first call to C<session>, then it will choose some sane defaults to
create the session object.

  # retrieve the session object
  my $session = $self->session;
 
  - or -
 
  # use the session object directly
  my $language = $self->session->param('language');


=head2 session_config

This method can be used to customize the functionality of the CGI::Application::Session module.
Calling this method does not mean that a new session object will be immediately created.
The session object will not be created until the first call to $self->session.  This
'lazy loading' can prevent expensive file system or database calls from being made if
the session is not needed during this request.

The recommended place to call C<session_config> is in the C<cgiapp_init>
stage of L<CGI::Application>.  If this method is called after the session object
has already been accessed, then it will die with an error message.

If this method is not called at all then a reasonable set of defaults
will be used (the exact default values are defined below).

The following parameters are accepted:

=over 4

=item CGI_SESSION_OPTIONS

This allows you to customize how the L<CGI::Session> object is created by providing a list of
options that will be passed to the L<CGI::Session> constructor.  Please see the documentation
for L<CGI::Session> for the exact syntax of the parameters.

=item COOKIE_PARAMS

This allows you to customize the options that are used when creating the session cookie.
For example you could provide an expiry time for the cookie by passing -expiry => '+24h'.
The -name and -value parameters for the cookie will be added automatically unless
you specifically override them by providing -name and/or -value parameters.
See the L<CGI::Cookie> docs for the exact syntax of the parameters.

=item SEND_COOKIE

If set to a true value, the module will automatically add a cookie header to the outgoing headers.
This option defaults to true.  If it is set to false, then no session cookies will be sent,
which may be useful if you prefer URL based sessions (it is up to you to pass the session ID in this case).

=back

The following example shows what options are set by default (ie this is what you
would get if you do not call session_config).

 $self->session_config(
          CGI_SESSION_OPTIONS => [ "driver:File", $self->query, {Directory=>'/tmp'} ],
          COOKIE_PARAMS       => {
                                   -path  => '/',
                                 },
          SEND_COOKIE         => 1,
 );

Here is a more customized example that uses the PostgreSQL driver and sets an
expiry and domain on the cookie.

 $self->session_config(
          CGI_SESSION_OPTIONS => [ "driver:PostgreSQL;serializer:Storable", $self->query, {Handle=>$dbh} ],
          COOKIE_PARAMS       => {
                                   -domain  => 'mydomain.com',
                                   -expires => '+24h',
                                   -path    => '/',
                                   -secure  => 1,
                                 },
 );
 

=head2 session_cookie

This method will add a cookie to the outgoing headers containing
the session ID that was assigned by the CGI::Session module.
This method is called automatically the first time $self->session
is accessed (unless SEND_COOKIE was set to false), so it will most
likely never need to be called manually.
It could be useful if you want to force the cookie header to be
sent out even if the session is not used on this request, or if
you want to manage the headers yourself by turning SEND_COOKIE to
false.

  # Force the cookie header to be sent including some
  # custom cookie parameters
  $self->session_cookie(-secure => 1, -expires => '+1w');


=head1 EXAMPLE

In a CGI::Application module:

  
  # configure the session once during the init stage
  sub cgiapp_init {
    my $self = shift;
 
    # Configure the session
    $self->session_config("driver:File", $self->query, {Directory=>'/tmp'});
    $self->session_config(
       CGI_SESSION_OPTIONS => [ "driver:PostgreSQL;serializer:Storable", $self->query, {Handle=>$self->dbh} ],
       COOKIE_PARAMS       => {
                                -expires => '+24h',
                                -path    => '/',
                              },
       SEND_COOKIE         => 1,
    );
 
  }
 
  sub cgiapp_prerun {
    my $self = shift;
 
    # Redirect to login, if necessary
    unless ( $self->session->param('~logged-in') ) {
      $self->prerun_mode('login');
    }
  }
 
  sub my_runmode {
    my $self = shift;
 
    # Load the template
    my $template = $self->load_tmpl('my_runmode.tmpl');
 
    # Add all the session parameters to the template
    $template->param($self->session->param_hashref());
 
    # return the template output
    return $template->output;
  }


=head1 BUGS

This is alpha software and as such, the features and interface
are subject to change.  So please check the Changes file when upgrading.
If you want to use CGI::Application::Session in a production
environment, please wait for version 1.0.


=head1 TODO

=over 4

=item *

I am considering adding support for other session modules in the future,
like L<Apache::Session> and possibly others if there is a demand.

=item *

Possibly add some tests to make sure cookies are accepted by the client.

=back


=head1 SEE ALSO

L<CGI::Application>, L<CGI::Session>, perl(1)


=head1 AUTHOR

Cees Hek <cees@crtconsulting.ca>


=head1 LICENSE

Copyright (C) 2004 Cees Hek <cees@crtconsulting.ca>

This library is free software. You can modify and or distribute it under the same terms as Perl itself.

=cut

