#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'CPAN::Mini::Webserver',
    VERSION_FROM => 'lib/CPAN/Mini/Webserver.pm',
    ABSTRACT     => 'Search and browse Mini CPAN',
    AUTHOR       => 'Leon Brocard <acme@astray.com>',
    LICENSE      => 'perl',
    PREREQ_PM    => {
        'App::Cache'               => '0',
        'Archive::Peek'            => '0.33',
        'CGI'                      => '3.16',
        'CPAN::Mini'               => '0.565',
        'File::Type'               => '0',
        'HTTP::Server::Simple'     => '0.34',
        'IO::Capture::Stdout'      => '0',
        'List::MoreUtils'          => '0',
        'MIME::Base64'             => '0',
        'Module::InstalledVersion' => '0',
        'Moose'                    => '0',
        'Parse::CPAN::Authors'     => '0',
        'Parse::CPAN::Whois'       => '0.02',
        'Parse::CPAN::Meta'        => '0',
        'Parse::CPAN::Packages'    => '2.28',
        'Path::Class'              => '0',
        'Pod::Simple::HTML'        => '0',
        'PPI'                      => '0',
        'PPI::HTML'                => '0',
        'Search::QueryParser'      => '0',
        'String::CamelCase'        => '0',
        'Template::Declare'        => '0.29',
        'Test::More'               => '0',
        'Text::Unidecode'          => '0',
    },
    'EXE_FILES' => ['bin/minicpan_webserver'],
);

