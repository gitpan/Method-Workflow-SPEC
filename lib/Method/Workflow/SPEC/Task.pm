package Method::Workflow::SPEC::Task;
use strict;
use warnings;

use base 'Method::Workflow::Task';
use Exodist::Util qw/array_accessors accessors/;

accessors 'it';
array_accessors qw/before after/;

sub process {
    my $self = shift;
    my ( $invocant, $result ) = @_;

    for my $before ( $self->before ) {
        $before->process( $invocant, $result );
    }

    $self->it->process( $invocant, $result )
        if $self->it;
    $self->SUPER::process( $invocant, $result );

    for my $after ( $self->after ) {
        $after->process( $invocant, $result );
    }
}

1;
