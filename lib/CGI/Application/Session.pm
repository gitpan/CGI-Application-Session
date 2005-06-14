package CGI::Application::Session;

use CGI::Session ();
use File::Spec ();
use CGI::Application 3.21;

use strict;
use vars qw($VERSION @EXPORT);

require Exporter;

@EXPORT = qw(
  session
  session_config
  session_cookie
);
sub import { goto &Exporter::import }

$VERSION = '0.07';

sub session {
    my $self = shift;

    if (!$self->{__CAP__SESSION_OBJ}) {
        # define the config hash if it doesn't exist to save some checks later
        $self->{__CAP__SESSION_CONFIG} = {} unless $self->{__CAP__SESSION_CONFIG};

        # gather parameters for the CGI::Session module from the user,
        #  or use some sane defaults
        my @params = ($self->{__CAP__SESSION_CONFIG}->{CGI_SESSION_OPTIONS}) ?
                        @{ $self->{__CAP__SESSION_CONFIG}->{CGI_SESSION_OPTIONS} } :
                        ('driver:File', $self->query, {Directory=>File::Spec->tmpdir});


        # CGI::Session only works properly with CGI.pm so extract the sid manually if
        # another module is being used
        if (ref $params[1] && ref $params[1] ne 'CGI') {
            my $sid = $params[1]->cookie(CGI::Session->name) || $params[1]->param(CGI::Session->name);
            $params[1] = $sid;
        }

        # create CGI::Session object
        $self->{__CAP__SESSION_OBJ} = CGI::Session->new(@params);

        # Set the default expiry if requested and if this is a new session
        if ($self->{__CAP__SESSION_CONFIG}->{DEFAULT_EXPIRY} && $self->{__CAP__SESSION_OBJ}->is_new) {
            $self->{__CAP__SESSION_OBJ}->expire($self->{__CAP__SESSION_CONFIG}->{DEFAULT_EXPIRY});
        }

        # add the cookie to the outgoing headers under the following conditions
        #  if the cookie doesn't exist,
        #  or if the session ID doesn't match what is in the current cookie,
        #  or if the session has an expiry set on it
        #  but don't send it if SEND_COOKIE is set to 0
        if (!defined $self->{__CAP__SESSION_CONFIG}->{SEND_COOKIE} || $self->{__CAP__SESSION_CONFIG}->{SEND_COOKIE}) {
            my $cid = $self->query->cookie(CGI::Session->name);
            if (!$cid || $cid ne $self->{__CAP__SESSION_OBJ}->id || $self->{__CAP__SESSION_OBJ}->expire()) {
                session_cookie($self);
            }
        }
    }

    return $self->{__CAP__SESSION_OBJ};
}

sub session_config {
    my $self = shift;

    if (@_) {
      die "Calling session_config after the session has already been created" if (defined $self->{__CAP__SESSION_OBJ});
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
        $self->{__CAP__SESSION_CONFIG}->{CGI_SESSION_OPTIONS} = delete $props->{CGI_SESSION_OPTIONS};
      }

      # Check for COOKIE_PARAMS
      if ($props->{COOKIE_PARAMS}) {
        die "session_config error:  parameter COOKIE_PARAMS is not a hash reference" if ref $props->{COOKIE_PARAMS} ne 'HASH';
        $self->{__CAP__SESSION_CONFIG}->{COOKIE_PARAMS} = delete $props->{COOKIE_PARAMS};
      }

      # Check for SEND_COOKIE
      if (defined $props->{SEND_COOKIE}) {
        $self->{__CAP__SESSION_CONFIG}->{SEND_COOKIE} = (delete $props->{SEND_COOKIE}) ? 1 : 0;
      }

      # Check for DEFAULT_EXPIRY
      if (defined $props->{DEFAULT_EXPIRY}) {
        $self->{__CAP__SESSION_CONFIG}->{DEFAULT_EXPIRY} = delete $props->{DEFAULT_EXPIRY};
      }

      # If there are still entries left in $props then they are invalid
      die "Invalid option(s) (".join(', ', keys %$props).") passed to session_config" if %$props;
    }

    $self->{__CAP__SESSION_CONFIG};
}

sub session_cookie {
    my $self = shift;
    my %options = @_;

    # merge in any parameters set by config_session
    if ($self->{__CAP__SESSION_CONFIG}->{COOKIE_PARAMS}) {
      %options = (%{ $self->{__CAP__SESSION_CONFIG}->{COOKIE_PARAMS} }, %options);
    }
    
    if (!$self->{__CAP__SESSION_OBJ}) {
        # The session object has not been created yet, so make sure we at least call it once
        my $tmp = $self->session;
    }

    $options{'-name'}    ||= CGI::Session->name;
    $options{'-value'}   ||= $self->session->id;
    $options{'-expires'} ||= _build_exp_time( $self->session->expires() ) if defined $self->session->expires();
    my $cookie = $self->query->cookie(%options);
    $self->header_add(-cookie => [$cookie]);
}

sub _build_exp_time {
    my $secs_until_expiry = shift;
    return unless defined $secs_until_expiry;

    # Add a plus sign unless the number is negative
    my $prefix = ($secs_until_expiry >= 0) ? '+' : '';

    # Add an 's' for "seconds".
    return $prefix.$secs_until_expiry.'s';
}

1;
__END__

=head1 NAME

CGI::Application::Session - DEPRICATED in favour of CGI::Application::Plugin::Session


=head1 SYNOPSIS

 use CGI::Application::Session;

 my $language = $self->session->param('language');

=head1 DESCRIPTION

This module has been depricated in favour of L<CGI::Application::Plugin::Session>.  The
only difference is in the name, so all functionality in this module is identical to that
in L<CGI::Application::Plugin::Session> version 0.07.


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

=item DEFAULT_EXPIRY

L<CGI::Session> Allows you to set an expiry time for the session.  You can set the
DEFAULT_EXPIRY option to have a default expiry time set for all newly created sessions.
It takes the same format as the $session->expiry method of L<CGI::Session> takes.
Note that it is only set for new session, not when a session is reloaded from the store.

=item COOKIE_PARAMS

This allows you to customize the options that are used when creating the session cookie.
For example you could provide an expiry time for the cookie by passing -expiry => '+24h'.
The -name and -value parameters for the cookie will be added automatically unless
you specifically override them by providing -name and/or -value parameters.
See the L<CGI::Cookie> docs for the exact syntax of the parameters.

NOTE:  If you change the name of the cookie by passing a -name parameter, remember to notify
CGI::Session of the change by calling CGI::Session->name('new_cookie_name').

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

This method is called automatically the first time $self->session is accessed
if SEND_COOKIE was set true, which is the default, so it will most likely never
need to be called manually.

NOTE that if you do choose to call it manually that a session object will
automatically be created if it doesn't already exist.  This removes the lazy
loading benefits of the plugin where a session is only created/loaded when
it is required.

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
    $self->session_config(
       CGI_SESSION_OPTIONS => [ "driver:PostgreSQL;serializer:Storable", $self->query, {Handle=>$self->dbh} ],
       DEFAULT_EXPIRY      => '+1w',
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


=head1 TODO

=over 4

=item *

I am considering adding support for other session modules in the future,
like L<Apache::Session> and possibly others if there is a demand.

=item *

Possibly add some tests to make sure cookies are accepted by the client.

=item *

Allow a callback to be executed right after a session has been created

=back


=head1 SEE ALSO

L<CGI::Application>, L<CGI::Session>, perl(1)


=head1 AUTHOR

Cees Hek <ceeshek@gmail.com>


=head1 LICENSE

Copyright (C) 2004, 2005 Cees Hek <ceeshek@gmail.com>

This library is free software. You can modify and or distribute it under the same terms as Perl itself.

=cut

