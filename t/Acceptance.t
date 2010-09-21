#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Method::Workflow::SPEC;

can_ok( __PACKAGE__, qw/describe it before_each after_each before_all after_all/ );

our @RUN_ORDER;

throws_ok(
    sub {
        no strict 'refs';
        &$_( 'name', sub { 1 });
    },
    qr/can only be used within a describe \{\} block/,
    "Cannot create spec element '$_' outside describe",
) for qw/before_all before_each it after_each after_all/;

describe a {
    push @RUN_ORDER => "Describe";

    before_all b { push @RUN_ORDER => "Before All" }
    before_each c { push @RUN_ORDER => "Before Each" }

    it d {
        push @RUN_ORDER => "It";
    }

    after_each e { push @RUN_ORDER => "After Each" }
    after_all f { push @RUN_ORDER => "After All" }

    describe aa {
        push @RUN_ORDER => "Describe Nested";

        before_all bb { push @RUN_ORDER => "Before All Nested" }
        before_each cc { push @RUN_ORDER => "Before Each Nested" }

        it dd {
            push @RUN_ORDER => "It Nested";
        }

        after_each ee { push @RUN_ORDER => "After Each Nested" }
        after_all ff { push @RUN_ORDER => "After All Nested" }
    }
}

run_workflow;

is_deeply(
    \@RUN_ORDER,
    [
        # Generators
        "Describe",
        "Describe Nested",

        # Root before all
        "Before All",

        # It and each
        "Before Each",
        "It",
        "After Each",

        # Nested
            "Before All Nested",

        "Before Each",
            "Before Each Nested",

                "It Nested",

            "After Each Nested",
        "After Each",

            "After All Nested",

        # Root after all
        "After All",
    ],
    "Order is correct"
);

done_testing;
