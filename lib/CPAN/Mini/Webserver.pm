package CPAN::Mini::Webserver;
use App::Cache;
use CPAN::Mini::App;
use CPAN::Mini::Webserver::Index;
use CPAN::Mini::Webserver::Templates;
use List::MoreUtils qw(uniq);
use Moose;
use Parse::CPAN::Authors;
use Parse::CPAN::Packages;
use Parse::CPAN::Meta;
use Pod::Simple::HTML;
use Path::Class;
use PPI;
use PPI::HTML;
use Template::Declare;

Template::Declare->init( roots => ['CPAN::Mini::Webserver::Templates'] );

if ( eval { require HTTP::Server::Simple::Bonjour } ) {
    extends 'HTTP::Server::Simple::Bonjour', 'HTTP::Server::Simple::CGI';
} else {
    extends 'HTTP::Server::Simple::CGI';
}

has 'hostname'            => ( is => 'rw' );
has 'cgi'                 => ( is => 'rw', isa => 'CGI' );
has 'directory'           => ( is => 'rw', isa => 'Path::Class::Dir' );
has 'scratch'             => ( is => 'rw', isa => 'Path::Class::Dir' );
has 'parse_cpan_authors'  => ( is => 'rw', isa => 'Parse::CPAN::Authors' );
has 'parse_cpan_packages' => ( is => 'rw', isa => 'Parse::CPAN::Packages' );
has 'pauseid'             => ( is => 'rw' );
has 'distvname'           => ( is => 'rw' );
has 'filename'            => ( is => 'rw' );
has 'index' => ( is => 'rw', isa => 'CPAN::Mini::Webserver::Index' );

our $VERSION = '0.38';

sub service_name {
    "$ENV{USER}'s minicpan_webserver";
}

sub get_file_from_tarball {
    my ( $self, $distribution, $filename ) = @_;

    my $file
        = file( $self->directory, 'authors', 'id', $distribution->prefix );

    die "unknown distribution format $file"
        unless ( $file =~ /\.(?:tar\.gz|tgz)$/ );

    # warn "tar fzxO $file $filename";
    my $contents = `tar fzxO $file $filename`;
    return $contents;
}

sub checksum_data_for_author {
    my ( $self, $pauseid ) = @_;

    my $file = file(
        $self->directory, 'authors', 'id',
        substr( $pauseid, 0, 1 ),
        substr( $pauseid, 0, 2 ),
        $pauseid, 'CHECKSUMS',
    );

    return unless -f $file;

    my ( $content, $cksum );
    {
        local $/;
        open my $fh, "$file" or die "$file: $!";
        $content = <$fh>;
        close $fh;
    }

    eval $content;

    return $cksum;
}

# this is a hook that HTTP::Server::Simple calls after setting up the
# listening socket. we use it load the indexes
sub after_setup_listener {
    my $self      = shift;
    my %config    = CPAN::Mini->read_config;
    my $directory = dir( glob $config{local} );
    $self->directory($directory);
    my $authors_filename = file( $directory, 'authors', '01mailrc.txt.gz' );
    my $packages_filename
        = file( $directory, 'modules', '02packages.details.txt.gz' );
    die "Please set up minicpan"
        unless defined($directory)
            && ( -d $directory )
            && ( -f $authors_filename )
            && ( -f $packages_filename );
    my $cache = App::Cache->new( { ttl => 60 * 60 } );
    my $parse_cpan_authors = $cache->get_code( 'parse_cpan_authors',
        sub { Parse::CPAN::Authors->new( $authors_filename->stringify ) } );
    my $parse_cpan_packages = $cache->get_code( 'parse_cpan_packages',
        sub { Parse::CPAN::Packages->new( $packages_filename->stringify ) } );

    $self->parse_cpan_authors($parse_cpan_authors);
    $self->parse_cpan_packages($parse_cpan_packages);

    my $scratch = dir( $cache->scratch );
    $self->scratch($scratch);

    my $index = CPAN::Mini::Webserver::Index->new;
    $self->index($index);
    $index->create_index( $parse_cpan_authors, $parse_cpan_packages );
}

sub handle_request {
    my ( $self, $cgi ) = @_;
    eval { $self->_handle_request($cgi) };
    if ($@) {
        print "HTTP/1.0 500\r\n", $cgi->header,
            "<h1>Internal Server Error</h1>", $cgi->escapeHTML($@);
    }
}

sub _handle_request {
    my ( $self, $cgi ) = @_;
    $self->cgi($cgi);
    $self->hostname( $cgi->virtual_host() );
    my $path = $cgi->path_info();

    my ( $raw, $download, $pauseid, $distvname, $filename );
    if ( $path =~ m{^/~} ) {
        ( undef, $pauseid, $distvname, $filename ) = split( '/', $path, 4 );
        $pauseid =~ s{^~}{};
    } elsif ( $path =~ m{^/(raw|download)/~} ) {
        ( undef, undef, $pauseid, $distvname, $filename )
            = split( '/', $path, 5 );
        ( $1 eq 'raw' ? $raw : $download ) = 1;
        $pauseid =~ s{^~}{};
    }
    $self->pauseid($pauseid);
    $self->distvname($distvname);
    $self->filename($filename);

    #warn "$raw / $download / $pauseid / $distvname / $filename";

    if ( $path eq '/' ) {
        $self->index_page();
    } elsif ( $path eq '/search/' ) {
        $self->search_page();
    } elsif ( $raw && $pauseid && $distvname && $filename ) {
        $self->raw_page();
    } elsif ( $download && $pauseid && $distvname ) {
        $self->download_file();
    } elsif ( $pauseid && $distvname && $filename ) {
        $self->file_page();
    } elsif ( $pauseid && $distvname ) {
        $self->distribution_page();
    } elsif ($pauseid) {
        $self->author_page();
    } elsif ( $path =~ m{^/perldoc} ) {
        $self->pod_page();
    } elsif ( $path =~ m{^/package/} ) {
        $self->package_page();
    } elsif ( $path eq '/static/css/screen.css' ) {
        $self->css_screen_page();
    } elsif ( $path eq '/static/css/print.css' ) {
        $self->css_print_page();
    } elsif ( $path eq '/static/css/ie.css' ) {
        $self->css_ie_page();
    } elsif ( $path eq '/static/images/logo.png' ) {
        $self->images_logo_page();
    } elsif ( $path eq '/static/images/favicon.png' ) {
        $self->images_favicon_page();
    } elsif ( $path eq '/favicon.ico' ) {
        $self->images_favicon_page();
    } elsif ( $path eq '/static/xml/opensearch.xml' ) {
        $self->opensearch_page();
    } else {
        print "HTTP/1.0 404 Not found\r\n";
        print $cgi->header,
            $cgi->start_html('Not found'),
            $cgi->h1('Not found'),
            $cgi->h2( 'path: ' . $path ),
            $cgi->end_html;
    }
}

sub index_page {
    my $self = shift;
    my $cgi  = $self->cgi;

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header;
    print Template::Declare->show('index');
}

sub search_page {
    my $self = shift;
    my $cgi  = $self->cgi;
    my $q    = $cgi->param('q');

    my $index   = $self->index;
    my @results = $index->search($q);
    my @authors
        = uniq grep { ref($_) eq 'Parse::CPAN::Authors::Author' } @results;
    my @distributions
        = uniq grep { ref($_) eq 'Parse::CPAN::Packages::Distribution' }
        @results;
    my @packages
        = uniq grep { ref($_) eq 'Parse::CPAN::Packages::Package' } @results;

    @authors = sort { $a->name cmp $b->name } @authors;

    @distributions = sort {
        my @acount = $a->dist =~ /-/g;
        my @bcount = $b->dist =~ /-/g;
        scalar(@acount) <=> scalar(@bcount)
            || $a->dist cmp $b->dist
    } @distributions;

    @packages = sort {
        my @acount = $a->package =~ /::/g;
        my @bcount = $b->package =~ /::/g;
        scalar(@acount) <=> scalar(@bcount)
            || $a->package cmp $b->package
    } @packages;

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header;
    print Template::Declare->show(
        'search',
        {   parse_cpan_authors => $self->parse_cpan_authors,
            q                  => $q,
            authors            => \@authors,
            distributions      => \@distributions,
            packages           => \@packages,
        }
    );
}

sub author_page {
    my $self    = shift;
    my $cgi     = $self->cgi;
    my $pauseid = $self->pauseid;

    my @distributions = sort { $a->distvname cmp $b->distvname }
        grep { $_->cpanid eq uc $pauseid }
        $self->parse_cpan_packages->distributions;
    my $author = $self->parse_cpan_authors->author( uc $pauseid );

    my $cksum = $self->checksum_data_for_author( uc $pauseid );
    my %dates;
    if ( not $@ and defined $cksum ) {
        foreach my $dist (@distributions) {
            $dates{ $dist->distvname } = $cksum->{ $dist->filename }->{mtime};
        }
    }

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header;
    print Template::Declare->show(
        'author',
        {   author        => $author,
            pauseid       => $pauseid,
            distributions => \@distributions,
            dates         => \%dates,
        }
    );
}

sub distribution_page {
    my $self      = shift;
    my $cgi       = $self->cgi;
    my $pauseid   = $self->pauseid;
    my $distvname = $self->distvname;

    my ($distribution)
        = grep { $_->cpanid eq uc $pauseid && $_->distvname eq $distvname }
        $self->parse_cpan_packages->distributions;

    my $filename = $distribution->distvname . "/META.yml";
    my $metastr  = $self->get_file_from_tarball( $distribution, $filename );
    my $meta     = {};
    my @yaml     = eval { Parse::CPAN::Meta::Load($metastr); };
    if ( not $@ ) {
        $meta = $yaml[0];
    }

    my $cksum_data = $self->checksum_data_for_author( uc $pauseid );
    $meta->{'release date'}
        = $cksum_data->{ $distribution->filename }->{mtime};

    my @filenames = $self->list_files($distribution);

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header;
    print Template::Declare->show(
        'distribution',
        {   author       => $self->parse_cpan_authors->author( uc $pauseid ),
            distribution => $distribution,
            pauseid      => $pauseid,
            distvname    => $distvname,
            filenames    => \@filenames,
            meta         => $meta,
            pcp          => $self->parse_cpan_packages,
        }
    );
}

sub pod_page {
    my $self      = shift;
    my $cgi       = $self->cgi;
    my ($pkgname) = $cgi->keywords;

    my $m = $self->parse_cpan_packages->package($pkgname);
    my $d = $m->distribution;

    my ( $pauseid, $distvname ) = ( $d->cpanid, $d->distvname );
    my $url = "/package/$pauseid/$distvname/$pkgname/";

    print "HTTP/1.0 302 OK\r\n";
    print $cgi->redirect($url);
}

sub file_page {
    my $self      = shift;
    my $cgi       = $self->cgi;
    my $pauseid   = $self->pauseid;
    my $distvname = $self->distvname;
    my $filename  = $self->filename;

    my ($distribution)
        = grep { $_->cpanid eq uc $pauseid && $_->distvname eq $distvname }
        $self->parse_cpan_packages->distributions;

    my $contents = $self->get_file_from_tarball( $distribution, $filename );

    my $parser = Pod::Simple::HTML->new;
    my $port   = $self->port;
    my $host   = $self->hostname;
    $parser->perldoc_url_prefix("http://$host:$port/perldoc?");
    $parser->index(0);
    $parser->no_whining(1);
    $parser->no_errata_section(1);
    $parser->output_string( \my $html );
    $parser->parse_string_document($contents);
    $html =~ s/^.*<!-- start doc -->//s;
    $html =~ s/<!-- end doc -->.*$//s;

#   $html
#       =~ s/^(.*%3A%3A.*)$/my $x = $1; ($x =~ m{indexItem}) ? 1 : $x =~ s{%3A%3A}{\/}g; $x/gme;

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header;
    print Template::Declare->show(
        'file',
        {   author       => $self->parse_cpan_authors->author( uc $pauseid ),
            distribution => $distribution,
            pauseid      => $pauseid,
            distvname    => $distvname,
            filename     => $filename,
            contents     => $contents,
            html         => $html,
        }
    );
}

sub download_file {
    my $self      = shift;
    my $cgi       = $self->cgi;
    my $pauseid   = $self->pauseid;
    my $distvname = $self->distvname;
    my $filename  = $self->filename;

    my ($distribution)
        = grep { $_->cpanid eq uc $pauseid && $_->distvname eq $distvname }
        $self->parse_cpan_packages->distributions;

    my $file
        = file( $self->directory, 'authors', 'id', $distribution->prefix );

    if ($filename) {
        my $contents;
        if ( $file =~ /\.(?:tar\.gz|tgz)$/ ) {
            $contents = `tar fzxO $file $filename`;
        } else {
            die "Unknown distribution format $file";
        }
        print "HTTP/1.0 200 OK\r\n";
        print $cgi->header(
            -content_type   => 'text/plain',
            -content_length => length $contents,
        );
        print $contents;
    } else {
        open my $fh, $file or do {
            print "HTTP/1.0 404 Not Found\r\n", $cgi->header, "Not Found";
            return;
        };

        print "HTTP/1.0 200 OK\r\n";
        my $content_type
            = $file =~ /zip/ ? 'application/zip' : 'application/x-gzip';
        print $cgi->header(
            -content_type        => $content_type,
            -content_disposition => "attachment; filename=" . $file->basename,
            -content_length      => -s $fh,
        );
        while (<$fh>) {
            print;
        }
    }
}

sub raw_page {
    my $self      = shift;
    my $cgi       = $self->cgi;
    my $pauseid   = $self->pauseid;
    my $distvname = $self->distvname;
    my $filename  = $self->filename;

    my ($distribution)
        = grep { $_->cpanid eq uc $pauseid && $_->distvname eq $distvname }
        $self->parse_cpan_packages->distributions;

    my $file
        = file( $self->directory, 'authors', 'id', $distribution->prefix );

    my $contents;
    if ( $file =~ /\.(?:tar\.gz|tgz)$/ ) {

        # warn "tar fzxO $file $filename";
        $contents = `tar fzxO $file $filename`;
    } else {
        die "Unknown distribution format $file";
    }

    my $html;

    if ( $filename =~ /\.(pm|pl|PL|t)$/ ) {
        my $document  = PPI::Document->new( \$contents );
        my $highlight = PPI::HTML->new( line_numbers => 0 );
        my $pretty    = $highlight->html($document);

        my $split = '<span class="line_number">';

        # turn significant whitespace into &nbsp;
        my @lines = map {
            $_ =~ s{</span>( +)}{"</span>" . ("&nbsp;" x length($1))}e;
            "$split$_";
        } split /$split/, $pretty;

        # remove the extra line number tag
        @lines = map { s{<span class="line_number">}{}; $_ } @lines;

        # remove newlines
        $_ =~ s{<br>}{}g foreach @lines;

        # link module names to search.cpan.org
        my $port = $self->port;
        my $host = $self->hostname;
        @lines = map {
            $_
                =~ s{<span class="word">([^<]+?::[^<]+?)</span>}{<span class="word"><a href="http://$host:$port/perldoc?$1">$1</a></span>};
            $_;
        } @lines;
        $html = join '', @lines;
    }

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header;
    print Template::Declare->show(
        'raw',
        {   author       => $self->parse_cpan_authors->author( uc $pauseid ),
            distribution => $distribution,
            filename     => $filename,
            pauseid      => $pauseid,
            distvname    => $distvname,
            contents     => $contents,
            html         => $html,
        }
    );
}

sub package_page {
    my $self = shift;
    my $cgi  = $self->cgi;
    my $path = $cgi->path_info();
    my ( $pauseid, $distvname, $package )
        = $path =~ m{^/package/(.+?)/(.+?)/(.+?)/$};

    my ($p) = grep {
               $_->package                 eq $package
            && $_->distribution->distvname eq $distvname
            && $_->distribution->cpanid    eq uc($pauseid)
    } $self->parse_cpan_packages->packages;
    my $distribution = $p->distribution;
    my @filenames    = $self->list_files($distribution);
    my $postfix      = $package;
    $postfix =~ s{^.+::}{}g;
    $postfix .= '.pm';
    my ($filename) = grep { $_ =~ /$postfix$/ }
        sort { length($a) <=> length($b) } @filenames;
    my $port = $self->port;
    my $host = $self->hostname;
    my $url  = "http://$host:$port/~$pauseid/$distvname/$filename";

    print "HTTP/1.0 302 OK\r\n";
    print $cgi->redirect($url);
}

sub list_files {
    my ( $self, $distribution ) = @_;
    my $file
        = file( $self->directory, 'authors', 'id', $distribution->prefix );
    my @filenames;

    if ( $file =~ /\.(?:tar\.gz|tgz)$/ ) {

        # warn "tar fzt $file";
        @filenames = sort `tar fzt $file`;
        chomp @filenames;
        @filenames = grep { $_ !~ m{/$} } @filenames;
    } else {
        die "Unknown distribution format $file";
    }
}

sub css_screen_page {
    my $self = shift;
    my $cgi  = $self->cgi;

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header( -type => 'text/css', -expires => '+1d' );
    print Template::Declare->show('css_screen');
}

sub css_print_page {
    my $self = shift;
    my $cgi  = $self->cgi;

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header( -type => 'text/css', -expires => '+1d' );
    print Template::Declare->show('css_print');
}

sub css_ie_page {
    my $self = shift;
    my $cgi  = $self->cgi;

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header( -type => 'text/css', -expires => '+1d' );
    print Template::Declare->show('css_ie');
}

sub images_logo_page {
    my $self = shift;
    my $cgi  = $self->cgi;

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header( -type => 'image/png', -expires => '+1d' );
    print Template::Declare->show('images_logo');
}

sub images_favicon_page {
    my $self = shift;
    my $cgi  = $self->cgi;

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header( -type => 'image/png', -expires => '+1d' );
    print Template::Declare->show('images_favicon');
}

sub opensearch_page {
    my $self = shift;
    my $cgi  = $self->cgi;

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header(
        -type    => 'application/opensearchdescription+xml',
        -expires => '+1d'
    );
    print Template::Declare->show('opensearch');
}

1;

__END__

=head1 NAME

CPAN::Mini::Webserver - Search and browse Mini CPAN

=head1 SYNOPSIS

  % minicpan_webserver
  
=head1 DESCRIPTION

This module is the driver that provides a web server that allows
you to search and browse Mini CPAN. First you must install
CPAN::Mini and create a local copy of CPAN using minicpan.
Then you may run minicpan_webserver and search and 
browse Mini CPAN at http://localhost:2963/.

You may access the Subversion repository at:

  http://code.google.com/p/cpan-mini-webserver/

And may join the mailing list at:

  http://groups.google.com/group/cpan-mini-webserver

=head1 AUTHOR

Leon Brocard <acme@astray.com>

=head1 COPYRIGHT

Copyright (C) 2008, Leon Brocard.

This module is free software; you can redistribute it or 
modify it under the same terms as Perl itself.
