#!perl
use strict;
use warnings;
use File::Slurp;
use MIME::Base64;
use Perl::Tidy;
use Template;

my $template = q{package CPAN::Mini::Webserver::Templates::Images;
use strict;
use warnings;
use MIME::Base64;
use Template::Declare::Tags;
use base 'Template::Declare';

[% FOREACH file IN files %]
  [% name = file.0 %]
  [% encoded = file.1 %]
template 'images_[% name %]' => sub {
my $self = shift;
my $encoded = <<'END';
[% encoded %]
END
outs_raw decode_base64($encoded);
};
[% END %]

1;
};

my $tt = Template->new;
$tt->process(
    \$template,
    {   files => [
            [ 'logo'    => encode_base64( read_file('images/logo.png') ) ],
            [ 'favicon' => encode_base64( read_file('images/favicon.png') ) ],
        ],
    },
    \my $perl,
) || die $template->error();
Perl::Tidy::perltidy( source => \$perl, destination => \my $tidied );
write_file( 'lib/CPAN/Mini/Webserver/Templates/Images.pm', $tidied );
