#!perl
use strict;
use warnings;

use Test::More;

use FindBin;
use lib $FindBin::Bin;
use WebserverTester;

use CPAN::Mini::Webserver;

eval {
    my $server = CPAN::Mini::Webserver->new();
    $server->after_setup_listener;
};

if ( $@ =~ /Please set up minicpan/ ) {
    plan skip_all => "CPAN::Mini mirror must be installed for testing: $@";
} else {
    plan tests => 36;
}

setup_server();
my $html;

# index
$html = html_page_ok('/');
like( $html, qr/Index/ );
like( $html, qr/Welcome to CPAN::Mini::Webserver/ );

# search for buffy
$html = html_page_ok('/search/', q => "buffy");
like( $html, qr/Search for .buffy./ );
like( $html, qr/Acme-Buffy-1.5/ );
like( $html, qr/Leon Brocard/ );

# show Leon
$html = html_page_ok('~lbrocard/', 'q' => undef );
like( $html, qr/Leon Brocard/ );
like( $html, qr/Acme-Buffy-1.5/ );
like( $html, qr/Tie-GHash-0.12/ );

# Show Acme-Buffy-1.5
$html = html_page_ok('~lbrocard/Acme-Buffy-1.5/');
like( $html, qr/Leon Brocard &gt; Acme-Buffy-1.5/ );
like( $html, qr/CHANGES/ );
like( $html, qr/demo_buffy\.pl/ );

# Show Acme-Buffy-1.5 CHANGES
$html = html_page_ok('~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/CHANGES');
like( $html,
    qr{Leon Brocard &gt; Acme-Buffy-1.5 &gt; Acme-Buffy-1.5/CHANGES} );
like( $html, qr/Revision history for Perl extension Buffy/ );

# Show Acme-Buffy-1.5 CHANGES Buffy.pm
$html = html_page_ok('~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/lib/Acme/Buffy.pm');
like( $html,
    qr{Leon Brocard &gt; Acme-Buffy-1.5 &gt; Acme-Buffy-1.5/lib/Acme/Buffy.pm}
);
like( $html, qr{An encoding scheme for Buffy the Vampire Slayer fans} );
like( $html, qr{See raw file} );

# Show Acme-Buffy-1.5 CHANGES Buffy.pm
$html = html_page_ok(
    '/raw/~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/lib/Acme/Buffy.pm');
like( $html,
    qr{Leon Brocard &gt; Acme-Buffy-1.5 &gt; Acme-Buffy-1.5/lib/Acme/Buffy.pm}
);
like( $html, qr{An encoding scheme for Buffy the Vampire Slayer fans} );

# Show package Acme::Buffy.pm
redirect_ok(
 'http://localhost:2963/~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/lib/Acme/Buffy.pm',
 '/package/lbrocard/Acme-Buffy-1.5/Acme::Buffy/'
);

# 'static' files
css_ok('/static/css/screen.css' );
css_ok('/static/css/print.css' );
css_ok('/static/css/ie.css' );
png_ok('/static/images/logo.png' );
png_ok('/static/images/favicon.png' );
png_ok('favicon.ico' );
opensearch_ok('/static/xml/opensearch.xml');

# 404
error404_ok('/this/doesnt/exist');

# downloads
$html = download_ok('/download/~LBROCARD/Acme-Buffy-1.5/Acme-Buffy-1.5/README');
like( $html, qr{Copyright \(c\) 2001});
