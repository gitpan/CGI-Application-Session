use Module::Build;

Module::Build->new(
    module_name => 'CGI::Application::Session',
    license => 'perl',
    requires => {
        'CGI::Application' => 3.21,
        'CGI::Session'     => 3.95,
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
    dist_author => 'Cees Hek <cees@crtconsulting.ca>',
    dist_abstract => 'Plugin that adds session support to CGI::Application',
)->create_build_script;

