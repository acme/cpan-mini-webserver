package CPAN::Mini::Webserver::Analyzer;
use strict;
use warnings;
use base qw( KinoSearch::Analysis::Analyzer );

sub analyze {
    my ( $self, $batch ) = @_;
    my $new_batch = KinoSearch::Analysis::TokenBatch->new();
    $batch->next;
    my $name    = $batch->get_text;
    my $pos_inc = 0;

    foreach my $part ( split /(?:\:\:| |-)/, $name ) {
        $part = lc $part;
        $new_batch->append( $part, 0, 1, $pos_inc++ );
        warn "[$name $part]" if $name =~ /buffy/i;
    }

    $batch->reset;
    $new_batch->reset;
    return $new_batch;
}

1;
