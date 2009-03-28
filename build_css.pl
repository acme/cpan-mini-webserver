#!perl
use strict;
use warnings;
use Cwd qw(cwd);
use CSS::Squish;
use File::Find::Rule;
use File::Slurp;
use Perl::Tidy;
use Template;
use YAML qw(LoadFile DumpFile);

foreach my $filename ( File::Find::Rule->new->file->in('root/static/css') ) {
    next if $filename =~ /my-screen\.css/;
    unlink($filename) || die $!;
}

my $settings = 'blueprint_0.7.1/lib/settings.yml';
my $conf     = LoadFile($settings);
$conf->{cpanminiwebserver}->{path} = cwd . '/root/static/css/';
DumpFile( $settings, $conf );
use YAML;

system "cd blueprint_0.7.1/lib && ruby compress.rb -p cpanminiwebserver";

die "CSS files not generated" unless -f 'root/static/css/screen.css';

my $template = q{package CPAN::Mini::Webserver::Templates::CSS;
use strict;
use warnings;
use Template::Declare::Tags;
use base 'Template::Declare';

[% FOREACH file IN files %]
  [% name = file.0 %]
  [% css = file.1 %]
template 'css_[% name %]' => sub {
my $self = shift;
my $css = <<'END';
[% css %]
END
outs_raw $css;
};
[% END %]

1;
};

my $tt = Template->new;
$tt->process(
    \$template,
    {   files => [
            [ 'ie'     => scalar read_file('root/static/css/ie.css') ],
            [ 'print'  => scalar read_file('root/static/css/print.css') ],
            [ 'screen' => scalar read_file('root/static/css/screen.css') ],
        ],
    },
    \my $perl,
) || die $template->error();
Perl::Tidy::perltidy( source => \$perl, destination => \my $tidied );
write_file( 'lib/CPAN/Mini/Webserver/Templates/CSS.pm', $tidied );
