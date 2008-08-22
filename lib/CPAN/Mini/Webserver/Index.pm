package CPAN::Mini::Webserver::Index;
use Moose;
use List::MoreUtils qw(uniq);
use Search::QueryParser;
use String::CamelCase qw(wordsplit);

has 'index' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

sub add {
    my ( $self, $key, $words ) = @_;
    my $index = $self->index;
    foreach my $word (@$words) {
        push @{ $index->{$word} }, $key;
    }
}

sub create_index {
    my ( $self, $parse_cpan_authors, $parse_cpan_packages ) = @_;

    foreach my $author ( $parse_cpan_authors->authors ) {
        my @words = split ' ', lc $author->name;
        push @words, lc $author->pauseid;
        $self->add( $author, \@words );
    }

    foreach my $distribution ( $parse_cpan_packages->latest_distributions ) {
        my @words;
        foreach my $word ( split '-', $distribution->dist ) {
            push @words, $word;
            push @words, wordsplit $word;
        }
        @words = map {lc} uniq @words;

        $self->add( $distribution, \@words );
    }

    foreach my $package ( $parse_cpan_packages->packages ) {
        my @words;
        foreach my $word ( split '::', $package->package ) {
            push @words, $word;
            push @words, wordsplit $word;
        }
        @words = map {lc} uniq @words;
        $self->add( $package, \@words );
    }

}

sub search {
    my ( $self, $q ) = @_;
    my $index = $self->index;
    my @results;

    my $qp = Search::QueryParser->new( rxField => qr/NOTAFIELD/, );
    my $query = $qp->parse( $q, 1 );
    unless ($query) {

        # warn "Error in query : " . $qp->err;
        return;
    }

    foreach my $part ( @{ $query->{'+'} } ) {
        my $value = $part->{value};
        my @words = split /(?:\:\:| |-)/, lc $value;
        foreach my $word (@words) {
            my @word_results = @{ $index->{$word} || [] };
            if (@results) {
                my %seen;
                $seen{$_} = 1 foreach @word_results;
                @results = grep { $seen{$_} } @results;
            } else {
                @results = @word_results;
            }
        }
    }

    foreach my $part ( @{ $query->{'-'} } ) {
        my $value        = $part->{value};
        my @word_results = $self->search_word($value);
        my %seen;
        $seen{$_} = 1 foreach @word_results;
        @results = grep { !$seen{$_} } @results;
    }

    return @results;
}

sub search_word {
    my ( $self, $word ) = @_;
    my $index = $self->index;
    my @results;
    my @words = split /(?:\:\:| |-)/, lc $word;
    foreach my $word (@words) {
        next unless exists $index->{$word};
        push @results, @{ $index->{$word} };
    }
    return @results;
}

1;
