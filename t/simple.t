#!perl
use strict;
use warnings;
use CGI;
use IO::Capture::Stdout;
use Test::More tests => 19;
use_ok 'CPAN::Mini::Webserver';

my $capture = IO::Capture::Stdout->new();

my $server = CPAN::Mini::Webserver->new();
$server->after_setup_listener;

# index
my $cgi = CGI->new;
$cgi->path_info('/');
my $html = make_request();
like( $html, qr/Index/ );
like( $html, qr/Welcome to CPAN::Mini::Webserver/ );

# search for buffy
$cgi->path_info('/search/');
$cgi->param( 'q', 'buffy' );
$html = make_request();
like( $html, qr/Search for .buffy./ );
like( $html, qr/Acme-Buffy-1.5/ );
like( $html, qr/Leon Brocard/ );

# show Leon
$cgi->path_info('~lbrocard/');
$cgi->param( 'q', undef );
$html = make_request();
like( $html, qr/Leon Brocard/ );
like( $html, qr/Acme-Buffy-1.5/ );
like( $html, qr/Tie-GHash-0.12/ );

# Show Acme-Buffy-1.5
$cgi->path_info('~lbrocard/Acme-Buffy-1.5/');
$html = make_request();
like( $html, qr/Leon Brocard &gt; Acme-Buffy-1.5/ );
like( $html, qr/CHANGES/ );
like( $html, qr/demo_buffy\.pl/ );

# Show Acme-Buffy-1.5 CHANGES
$cgi->path_info('~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/CHANGES');
$html = make_request();
like( $html,
    qr{Leon Brocard &gt; Acme-Buffy-1.5 &gt; Acme-Buffy-1.5/CHANGES} );
like( $html, qr/Revision history for Perl extension Buffy/ );

# Show Acme-Buffy-1.5 CHANGES Buffy.pm
$cgi->path_info('~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/lib/Acme/Buffy.pm');
$html = make_request();
like( $html,
    qr{Leon Brocard &gt; Acme-Buffy-1.5 &gt; Acme-Buffy-1.5/lib/Acme/Buffy.pm}
);
like( $html, qr{An encoding scheme for Buffy the Vampire Slayer fans} );
like( $html, qr{See raw file} );

# Show Acme-Buffy-1.5 CHANGES Buffy.pm
$cgi->path_info(
    '/raw/~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/lib/Acme/Buffy.pm');
$html = make_request();
like( $html,
    qr{Leon Brocard &gt; Acme-Buffy-1.5 &gt; Acme-Buffy-1.5/lib/Acme/Buffy.pm}
);
like( $html, qr{An encoding scheme for Buffy the Vampire Slayer fans} );

sub make_request {
    $capture->start;
    $server->handle_request($cgi);
    $capture->stop;
    my $buffer = join '', $capture->read;
    return $buffer;
}

