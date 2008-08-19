package Handy;
use base qw(Exporter);

use strict;
use warnings;

use Test::Builder;
my $Tester = Test::Builder->new;

use IO::Capture::Stdout;
use CGI;

our @EXPORT;
my $server;

sub setup_server {
    $server = CPAN::Mini::Webserver->new(2963);
    $server->after_setup_listener;
};
push @EXPORT, "setup_server";

sub page {
    my $path = shift;
    my $cgi = CGI->new;
    $cgi->path_info($path);
    while (@_) {
        my $name = shift;
        my $value = shift;
        $cgi->param($name, $value);
    }
    my $response = make_request($cgi);
    return $response;
}
push @EXPORT, "page";

sub make_request {
    my $cgi = shift;
    my $capture = IO::Capture::Stdout->new();
    $capture->start;
    $server->handle_request($cgi);
    $capture->stop;
    my $buffer = join '', $capture->read;
    return $buffer;
}

"I wonder if dom's script that looks
for true values at the end of modules
looks in test modules too?";
