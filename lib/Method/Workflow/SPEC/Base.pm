package Method::Workflow::SPEC::Base;
use strict;
use warnings;

use Carp qw/croak/;

use base 'Method::Workflow::Base';

our @CARP_NOT = qw/ Method::Workflow::Base Method::Workflow /;

# Override init such that it bails if it is not created for a parent of type
# describe.

sub init {
    my $self = shift;
    my %params = @_;

    croak $self->keyword . " can only be used within a describe {} block."
        unless $params{ parent }->isa( 'Method::Workflow::SPEC' );

    return $self;
}

1;
