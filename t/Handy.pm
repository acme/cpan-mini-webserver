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

sub html_page_ok {
    my $path = shift;
    my $response = make_request($path, @_);
    
    # basic "is my response correct" tests
    $Tester->like($response, qr/200 OK/, "page returned 200 OK");
    $Tester->like($response, qr{Content-Type: text/html}, "html mime");
    $Tester->like($response, qr/<html/, "page had a html tag in it");
    
    return $response;
}
push @EXPORT, "html_page_ok";

sub css_ok {
    my $path = shift;
    my $response = make_request($path, @_);
    
    # basic "is my response correct" tests
    $Tester->like($response, qr/200 OK/, "page returned 200 OK");
    $Tester->like($response, qr{Content-Type: text/css}, "css mime");
    
    return $response;
}
push @EXPORT, "css_ok";

sub png_ok {
    my $path = shift;
    my $response = make_request($path, @_);
    
    # basic "is my response correct" tests
    $Tester->like($response, qr/200 OK/, "page returned 200 OK");
    $Tester->like($response, qr{Content-Type: image/png}, "css mime");
    
    return $response;
}
push @EXPORT, "png_ok";


sub redirect_ok {
    my $location = shift;
    my $path = shift;
    my $response = make_request($path, @_);
    
    $Tester->like( $response, qr{HTTP/1.0 302 OK}, "returned 302");
    $Tester->like( $response, qr{Status: 302 Found}, "status is 302 found");
    $Tester->like( $response,
        qr{Location: $location},
        "went to the right place"
    );
    
    return $response;
}
push @EXPORT, "redirect_ok";

sub make_request {
    my $path = shift;
    
    my $cgi = CGI->new;
    $cgi->path_info($path);
    while (@_) {
        my $name = shift;
        my $value = shift;
        $cgi->param($name, $value);
    }
    
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
