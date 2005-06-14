use Module::Build;

Module::Build->new(
    module_name => 'CGI::Application::Session',
    license => 'perl',
    requires => {
        'CGI::Application' => 3.21,
        'CGI::Session'     => 3.95,
        'File::Spec'       => 0,
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
    dist_author => 'Cees Hek <ceeshek@gmail.com>',
    dist_abstract => 'DEPRICATED in favour of CGI::Application::Plugin::Session',
)->create_build_script;

