#!perl
use strict;
use warnings;

use Test::More;
use CPAN::Mini::Webserver;

eval {
    my $server = CPAN::Mini::Webserver->new();
    $server->after_setup_listener;
};
if ( $@ =~ /Please set up minicpan/ ) {
    plan skip_all => "CPAN::Mini mirror must be installed for testing: $@";
} else {
    plan tests => 21;
}

setup_server();
my $html;

# index
$html = page('/');
like( $html, qr/Index/ );
like( $html, qr/Welcome to CPAN::Mini::Webserver/ );

# search for buffy
$html = page('/search/', q => "buffy");
like( $html, qr/Search for .buffy./ );
like( $html, qr/Acme-Buffy-1.5/ );
like( $html, qr/Leon Brocard/ );

# show Leon
$html = page('~lbrocard/', 'q' => undef );
like( $html, qr/Leon Brocard/ );
like( $html, qr/Acme-Buffy-1.5/ );
like( $html, qr/Tie-GHash-0.12/ );

# Show Acme-Buffy-1.5
$html = page('~lbrocard/Acme-Buffy-1.5/');
like( $html, qr/Leon Brocard &gt; Acme-Buffy-1.5/ );
like( $html, qr/CHANGES/ );
like( $html, qr/demo_buffy\.pl/ );

# Show Acme-Buffy-1.5 CHANGES
$html = page('~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/CHANGES');
like( $html,
    qr{Leon Brocard &gt; Acme-Buffy-1.5 &gt; Acme-Buffy-1.5/CHANGES} );
like( $html, qr/Revision history for Perl extension Buffy/ );

# Show Acme-Buffy-1.5 CHANGES Buffy.pm
$html = page('~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/lib/Acme/Buffy.pm');
like( $html,
    qr{Leon Brocard &gt; Acme-Buffy-1.5 &gt; Acme-Buffy-1.5/lib/Acme/Buffy.pm}
);
like( $html, qr{An encoding scheme for Buffy the Vampire Slayer fans} );
like( $html, qr{See raw file} );

# Show Acme-Buffy-1.5 CHANGES Buffy.pm
$html = page (
    '/raw/~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/lib/Acme/Buffy.pm');
like( $html,
    qr{Leon Brocard &gt; Acme-Buffy-1.5 &gt; Acme-Buffy-1.5/lib/Acme/Buffy.pm}
);
like( $html, qr{An encoding scheme for Buffy the Vampire Slayer fans} );

# Show package Acme::Buffy.pm
$html = page('/package/lbrocard/Acme-Buffy-1.5/Acme::Buffy/');
like( $html, qr{HTTP/1.0 302 OK} );
like( $html, qr{Status: 302 Found} );
like( $html,
    qr{Location: http://localhost:2963/~lbrocard/Acme-Buffy-1.5/Acme-Buffy-1.5/lib/Acme/Buffy.pm}
);
