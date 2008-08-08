#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'CPAN::Mini::Webserver',
    VERSION_FROM => 'lib/CPAN/Mini/Webserver.pm',
    AUTHOR       => 'Leon Brocard <acme@astray.com>',
    LICENSE      => 'perl',
    PREREQ_PM    => {
        'App::Cache'                => '0',
        'Convert::UU'               => '0',
        'CPAN::Mini'                => '0.565',
        'HTTP::Server::Simple::CGI' => '0.34',
        'IO::Capture::Stdout'       => '0',
        'Moose'                     => '0',
        'Parse::CPAN::Authors'      => '0',
        'Parse::CPAN::Packages'     => '0',
        'Path::Class'               => '0',
        'Pod::Simple::HTML'         => '0',
        'Perl6::Say'                => '0',
        'PPI'                       => '0',
        'PPI::HTML'                 => '0',
        'Template::Declare'         => '0.29',
        'Test::More'                => '0',
    },
    'EXE_FILES' => ['bin/minicpan_webserver'],
);

