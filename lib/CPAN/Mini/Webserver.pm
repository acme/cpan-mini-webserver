package CPAN::Mini::Webserver;
use App::Cache;
use CPAN::Mini::App;
use CPAN::Mini::Webserver::Templates;
use Moose;
use Parse::CPAN::Authors;
use Parse::CPAN::Packages;
use Pod::Simple::HTML;
use Path::Class;
use PPI;
use PPI::HTML;
use Template::Declare;
Template::Declare->init( roots => ['CPAN::Mini::Webserver::Templates'] );

extends 'HTTP::Server::Simple::CGI';
has 'cgi'                 => ( is => 'rw', isa => 'CGI' );
has 'directory'           => ( is => 'rw', isa => 'Path::Class::Dir' );
has 'parse_cpan_authors'  => ( is => 'rw', isa => 'Parse::CPAN::Authors' );
has 'parse_cpan_packages' => ( is => 'rw', isa => 'Parse::CPAN::Packages' );
has 'pauseid'             => ( is => 'rw' );
has 'distvname'           => ( is => 'rw' );
has 'filename'            => ( is => 'rw' );

our $VERSION = '0.35';

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
}

sub handle_request {
    my ( $self, $cgi ) = @_;
    $self->cgi($cgi);
    my $path = $cgi->path_info();

    my ( $raw, $pauseid, $distvname, $filename );
    if ( $path =~ m{^/~} ) {
        ( undef, $pauseid, $distvname, $filename ) = split( '/', $path, 4 );
        $pauseid =~ s{^~}{};
    } elsif ( $path =~ m{^/raw/~} ) {
        ( undef, undef, $pauseid, $distvname, $filename )
            = split( '/', $path, 5 );
        $raw = 1;
        $pauseid =~ s{^~}{};
    }
    $self->pauseid($pauseid);
    $self->distvname($distvname);
    $self->filename($filename);

    #warn "$raw / $pauseid / $distvname / $filename";

    if ( $path eq '/' ) {
        $self->index_page();
    } elsif ( $path eq '/search/' ) {
        $self->search_page();
    } elsif ( $raw && $pauseid && $distvname && $filename ) {
        $self->raw_page();
    } elsif ( $pauseid && $distvname && $filename ) {
        $self->file_page();
    } elsif ( $pauseid && $distvname ) {
        $self->distribution_page();
    } elsif ($pauseid) {
        $self->author_page();
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

    my @authors = sort { $a->name cmp $b->name }
        grep { $_->name =~ /$q/i || $_->pauseid =~ /$q/i }
        $self->parse_cpan_authors->authors;
    my @distributions = sort {
        my @acount = $a->dist =~ /-/g;
        my @bcount = $b->dist =~ /-/g;
        scalar(@acount) <=> scalar(@bcount)
            || $a->dist cmp $b->dist
        }
        grep {
        $_->dist && $_->dist =~ /$q/i
        } $self->parse_cpan_packages->latest_distributions;
    my @packages = sort {
        my @acount = $a->package =~ /::/g;
        my @bcount = $b->package =~ /::/g;
        scalar(@acount) <=> scalar(@bcount)
            || $a->package cmp $b->package
        } grep {
        $_->package =~ /$q/i
        } $self->parse_cpan_packages->packages;

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

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header;
    print Template::Declare->show(
        'author',
        {   author        => $author,
            pauseid       => $pauseid,
            distributions => \@distributions,
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

    my @filenames = $self->list_files($distribution);

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header;
    print Template::Declare->show(
        'distribution',
        {   author       => $self->parse_cpan_authors->author( uc $pauseid ),
            distribution => $distribution,
            pauseid      => $pauseid,
            distvname    => $distvname,
            filenames    => \@filenames
        }
    );
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

    my $file
        = file( $self->directory, 'authors', 'id', $distribution->prefix );

    my $contents;
    if ( $file =~ /\.(?:tar\.gz|tgz)$/ ) {

        # warn "tar fzxO $file $filename";
        $contents = `tar fzxO $file $filename`;
    } else {
        die "Unknown distribution format $file";
    }

    my $parser = Pod::Simple::HTML->new;
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

    if ( $filename =~ /\.(pm|pl|PL)$/ ) {
        my $document  = PPI::Document->new( \$contents );
        my $highlight = PPI::HTML->new( line_numbers => 0 );
        my $pretty    = $highlight->html($document);

        my $split = '<span class="line_number">';

        # turn significant whitespace into &nbsp;
        my @lines = map {
            $_ =~ s{</span>( +)}{"</span>" . ("&nbsp;" x length($1))}e;
            "$split$_";
        } split /$split/, $pretty;

        # right-justify the line number
        #  @lines = map {
        #    s{<span class="line_number"> ?(\d+) ?:}{
        #      my $line = $1;
        #      my $size = 4 - (length($1));
        #      $size = 0 if $size < 0;
        #      '<span class="line_number">' . ("&nbsp;" x $size) . "$line:"}e;
        #    $_;
        #  } @lines;

        # remove newlines
        $_ =~ s{<br>}{}g foreach @lines;

        # link module names to search.cpan.org
        @lines = map {
            $_
                =~ s{<span class="word">([^<]+?::[^<]+?)</span>}{<span class="word"><a href="http://search.cpan.org/perldoc?$1">$1</a></span>};
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
    my $url = "http://localhost:8080/~$pauseid/$distvname/$filename";

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
browse Mini CPAN at http://localhost:8080/.

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
