#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Method::Workflow::SPEC ':ordered';
use Data::Dumper;

my @errors;
my @ran;
my @aorder;
root_workflow->error_handler( sub { push @errors => @_ });

describe x {
    it xxx {
        push @ran => 'xxx';
        die "Error!";
        push @ran => 'I should not be here!';
    }
}

describe a (random => 1) {
    it a1 {
        push @aorder => 'a1';
        push @ran => 'a1';
    }

    it a2 {
        push @aorder => 'a2';
        push @ran => 'a2';
    }

    it a3 {
        push @aorder => 'a3';
        push @ran => 'a3';
    }
}

describe b { it b { push @ran => 'b' }}
describe c { it c { push @ran => 'c' }}

my $result = run_workflow;
my ( $wf, $error ) = @{ $errors[0]};
like( $error, qr/Error! at/, "Workflow element error caught" );
is( @aorder, 3, "All 3 'a' blocks ran" );
is_deeply(
    \@ran,
    [ 'xxx', @aorder, 'b', 'c' ],
    "Ran everything, correct order"
);

done_testing;
