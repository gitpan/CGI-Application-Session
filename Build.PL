use Module::Build;
my $class = Module::Build->subclass(
     class => 'My::Builder',
     code => q{
        sub ACTION_dist {
            my $self = shift;
            `perldoc -t lib/CGI/Application/Session>README`;
            $self->SUPER::ACTION_dist;
        }
    },
);


$class->new(
    module_name => 'CGI::Application::Session',
    license => 'perl',
    requires => {
        'CGI::Application' => 3.0,
        'CGI::Session'     => 3.95,
    },
    create_makefile_pl => 'traditional',
)->create_build_script;

