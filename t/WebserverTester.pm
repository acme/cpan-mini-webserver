package WebserverTester;
use base qw(Exporter);

use strict;
use warnings;

use Test::Builder;

use IO::Capture::Stdout;

sub IO::Capture::Tie_STDx::BINMODE {

    # this is so we can call binmode to do utf-8 output
    # in the real world and still use IO::Capture::Stdout here.
}

use HTTP::Response;
use CGI;

our @EXPORT;
my $server;

{

    # create a bunch of testing routines that we use internally
    # these SILENTLY return 1 on success, but on failure return 0
    # and spit out a failing test case
    #
    # This allows us to easily write compound tests

    my $Tester = Test::Builder->new;

    sub is_num($$;$) {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        return 1 if $_[0] == $_[1];
        $Tester->is_num( $_[0], $_[1], $Test::name );
        $Tester->diag( $_[2] ) if $_[2];
        return 0;
    }

    sub is_eq($$;$) {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        return 1 if $_[0] eq $_[1];
        $Tester->is_eq( $_[0], $_[1], $Test::name );
        $Tester->diag( $_[2] ) if $_[2];
        return 0;
    }

    sub like($$;$) {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        return 1 if $_[0] =~ $_[1];
        $Tester->like( $_[0], $_[1], $Test::name );
        $Tester->diag( $_[2] ) if $_[2];
        return 0;
    }

    sub ok() {
        $Tester->ok( 1, $Test::name );
        return 1;
    }

    sub skip_all() {
        $Tester->plan( skip_all =>
                "CPAN::Mini mirror must be installed for testing: $@" );
        exit;
    }
}

sub setup_server {
    eval {
        $server = CPAN::Mini::Webserver->new(2963);
        $server->after_setup_listener;
    };

    skip_all() if $@ && $@ =~ /Please set up minicpan/;

    return $server;
}
push @EXPORT, "setup_server";

sub html_page_ok {
    my $path = shift;
    my ( $code, $mime, $content ) = make_request( $path, @_ );

    # basic "is my response correct" tests
    local $Test::name = "html page from '$path'";
    return unless is_num $code, 200,            "when checking status";
    return unless like $mime,   qr{^text/html}, "when checking html mimetype";
    return
        unless like $content, qr/<html/,
        "when checking page had a html tag in it";
    ok;

    return $content;
}
push @EXPORT, "html_page_ok";

sub css_ok {
    my $path = shift;
    my ( $code, $mime, $content ) = make_request( $path, @_ );

    # basic "is my response correct" tests
    local $Test::name = "css from '$path'";
    return unless is_num $code, 200,           "when checking status";
    return unless like $mime,   qr{^text/css}, "css mimetype";
    ok;

    return $content;
}
push @EXPORT, "css_ok";

sub png_ok {
    my $path = shift;
    my ( $code, $mime, $content ) = make_request( $path, @_ );

    # basic "is my response correct" tests
    local $Test::name = "png from '$path'";
    return unless is_num $code, 200,            "when checking status";
    return unless like $mime,   qr{^image/png}, "when checking css mimetype";
    ok;

    return $content;
}
push @EXPORT, "png_ok";

sub opensearch_ok {
    my $path = shift;
    my ( $code, $mime, $content ) = make_request( $path, @_ );

    # basic "is my response correct" tests
    local $Test::name = "opensearch from '$path'";
    return unless is_num $code, 200, "when checking status";
    return
        unless like $mime, qr{^application/opensearchdescription},
        "when checking opensearch mimetype";
    return unless like $content, qr/<\?xml/, "when checking for an xml tag";
    ok;

    return $content;
}
push @EXPORT, "opensearch_ok";

sub redirect_ok {
    my $location = shift;
    my $path     = shift;
    my ( $code, $mime, $content, $response ) = make_request( $path, @_ );

    local $Test::name = "redirect from '$path'";
    return unless is_num $code, 302, "when checking status";
    return
        unless is_eq $response->header("Status"), "302 Found",
        "when checking Status";
    return
        unless is_eq $response->header("Location"),
        $location,
        "when checking went to the right place";
    ok;

    return $response;
}
push @EXPORT, "redirect_ok";

sub error404_ok {
    my $path = shift;
    my ( $code, $mime, $content, $response ) = make_request( $path, @_ );

    local $Test::name = "error 404 for '$path'";
    return unless is_num $code, 404, "when checking status";
    ok;

    return $response;
}
push @EXPORT, "error404_ok";

sub download_ok {
    my $path = shift;
    my ( $code, $mime, $content ) = make_request( $path, @_ );

    local $Test::name = "download for '$path'";
    return unless is_num $code, 200, "when checking status";
    return unless like $mime, qr{^text/plain}, "when checking plain mimetype";
    ok;

    return $content;
}
push @EXPORT, "download_ok";

sub download_gzip_ok {
    my $path = shift;
    my ( $code, $mime, $content ) = make_request( $path, @_ );

    local $Test::name = "download for '$path'";
    return unless is_num $code, 200, "when checking status";
    return
        unless like $mime, qr{^application/x-gzip},
        "when checking plain mimetype";
    ok;

    return $content;
}
push @EXPORT, "download_gzip_ok";

sub make_request {
    my $path = shift;

    my $cgi = CGI->new;
    $cgi->path_info($path);
    while (@_) {
        my $name  = shift;
        my $value = shift;
        $cgi->param( $name, $value );
    }

    my $capture = IO::Capture::Stdout->new();
    $capture->start;
    $server->handle_request($cgi);
    $capture->stop;
    my $buffer = join '', $capture->read;

    my $r = HTTP::Response->parse($buffer);
    return wantarray
        ? (
        $r->code                   || "",
        $r->header("Content-Type") || "",
        $r->content                || "", $r
        )
        : $r->as_string;
}

"I wonder if dom's script that looks for true values at the end of modules looks in test modules too?";
