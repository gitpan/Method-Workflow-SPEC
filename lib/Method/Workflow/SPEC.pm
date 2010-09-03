package Method::Workflow::SPEC;
use strict;
use warnings;

use Method::Workflow;
use base 'Method::Workflow::Base';

our $VERSION = '0.001';

use aliased 'Method::Workflow::SPEC::It';
use aliased 'Method::Workflow::SPEC::BeforeEach';
use aliased 'Method::Workflow::SPEC::AfterEach';
use aliased 'Method::Workflow::SPEC::BeforeAll';
use aliased 'Method::Workflow::SPEC::AfterAll';
use aliased 'Method::Workflow::SPEC::Task';
export( $_, 'fennec' ) for qw/it before_all after_all before_each after_each/;

use Method::Workflow::Meta qw/ meta_for /;
use Scalar::Util qw/ blessed /;
use Try::Tiny;

our @ORDER = qw/ ordered sorted random /;
accessors @ORDER, 'parent_task';
keyword 'describe';

sub import_hook {
    my ( $class, $caller, $specs ) = @_;
    my $meta = meta_for( __PACKAGE__ );
    $meta->prop( $caller, $specs );
}

sub post_run_hook {
    'SPEC' => sub {
        my %params = @_;

        my $out_ref = $params{out};

        return unless "$params{owner}" eq "$params{root}";

        my ( @out, @tasks );
        for my $item ( @$out_ref ) {
            my $list = ( blessed( $item ) && $item->isa( Task ))
                ? \@tasks
                : \@out;
                push @$list => $item;
        }

        my $task = Task->new( subtasks_ref => \@tasks );
        try { push @out => $task->run_task( $params{root} )                      }
        catch { Method::Workflow::Base::handle_error( $task, $params{root}, $_, )};

        @$out_ref = @out;
    },
}

sub run {
    my ( $self, $root ) = @_;
    my @out = $self->method->( $root, $self );
    my ( @tasks );
    my $meta = meta_for( $self );

    # * Pull all before/after/it items from meta
    my @before_each = $meta->pull_items( BeforeEach );
    my @after_each  = $meta->pull_items( AfterEach  );
    my @before_all  = $meta->pull_items( BeforeAll  );
    my @after_all   = $meta->pull_items( AfterAll   );
    my @it          = $meta->pull_items( It         );

    # Find any ordering
    my ( $order ) = grep { $self->$_ } @ORDER;

    # Add before/after each to nested describes.
    my @child_specs = $meta->items( __PACKAGE__ );
    for my $child ( @child_specs ) {
        meta_for( $child )->add_item( $_ ) for @before_each, @after_each;
    }

    # Create tasks for 'it' elements
    for my $it ( @it ) {
        push @tasks => Task->new(
            before_each_ref => \@before_each,
            after_each_ref  => \@after_each,
            it              => $it,
            describe        => $self,
        );
    }

    # If there are wrapping items or config create a wrapping task.
    if ( @before_all || @after_all || $order ) {
        @tasks = ( Task->new(
            before_all_ref  => \@before_all,
            after_all_ref   => \@after_all,
            subtasks_ref    => [@tasks],
            _ordering       => $order || undef,
            describe        => $self,
        ));

        for my $child ( @child_specs ) {
            $child->parent_task( $tasks[0] ) for @child_specs;
        }
    }

    for my $child ( @child_specs ) {
        $child->set_order_unless_set( $order )
            if $order && !grep { $child->$_ } @ORDER;
    }

    if ( $self->parent_task ) {
        $self->parent_task->add_subtasks( @tasks );
        return @out;
    }

    return ( @tasks, @out );
}

1;

=head1 NAME

Method::Workflow::SPEC - RSPEC keywords + workflow

=head1 DESCRIPTION

This module is an implementation of RSPEC on top of L<Method::Workflow>. This
provides the basic keywords to create an RSPEC workflow.

=head1 EARLY VERSION WARNING

This is an early version, better tests are needed. Most documented features
should work fine though.

=head1 SYNOPSYS

From the acceptance test:

    #!/usr/bin/perl
    use strict;
    use warnings;
    use Test::More;
    use Method::Workflow::SPEC;

    #################
    # Define the workflow

    start_class_workflow;
    our @RUN_ORDER;

    describe aa {
        push @RUN_ORDER => "Describe";

        before_all cc { push @RUN_ORDER => "Before All" }
        before_each bb { push @RUN_ORDER => "Before Each" }

        it dd {
            push @RUN_ORDER => "It";
        }

        after_each ff { push @RUN_ORDER => "After Each" }
        after_all ee { push @RUN_ORDER => "After All" }

        describe aa {
            push @RUN_ORDER => "Describe Nested";

            before_all cc { push @RUN_ORDER => "Before All Nested" }
            before_each bb { push @RUN_ORDER => "Before Each Nested" }

            it dd {
                push @RUN_ORDER => "It Nested";
            }

            after_each ff { push @RUN_ORDER => "After Each Nested" }
            after_all ee { push @RUN_ORDER => "After All Nested" }
        }
    }

    end_class_workflow;

    ##################
    # Run the workflow
    run_workflow;

    ##################
    # Verify the results

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

=head1 KEYWORDS

All keywords take a name and codeblock. Name is not currently optional, this
may change.

=over 4

=item describe NAME { ... }

Create a root SPEC workflow element. These are run first to generate the tasks
that will be run. These may be nested.

=item it NAME { ... }

Create a task node, these are the blocks that should produce results or accomplish
work. These may not be nested, but there can be multiple within the same
describe block.

=item before_each NAME { ... }

Create a setup block that should be run once for each 'it' block prior to the run
of that 'it' block.

=item after_each NAME { ... }

Create a setup block that should be run once before any 'it' block is run.

=item before_all NAME { ... }

Create a teardown block that should be run once for each 'it' block after the run
of that 'it' block.

=item after_all NAME { ... }

Create a teardown block that should be run once before any 'it' block is run.

=back

=head1 USE IN TESTING

Works as expected, use L<Test::More>. Checks can be placed in any block.

=head2 ENCAPSULATING ERRORS

Use the 'error_handler' keyword (see L<Method::Workflow::Base> the exports
section) to create a handler that lets your tests continue if an exception is
thrown from any block.

    #!/usr/bin/perl
    use strict;
    use warnings;
    use Test::More;
    use Method::Workflow::SPEC;

    start_class_workflow;

    my @errors;
    error_handler( sub { @errors = @_ });

    describe aa { it xxx { die "Error!" }}
    describe bb { ok( 1, "I still run!" )}

    end_class_workflow;
    run_workflow;

    my ( $item, $root, $error ) = @errors;
    like( $error, qr/Error! at/, "Workflow element error caught" );

    done_testing;

=head2 ORDERING TESTS

You can specify an order at the class level and/or the block level. The
ordering will carry-down to nested elements until a new order is specified.

There are 3 orderng options:

=over 2

=item ordered

The default, run in the order they were defined.

=item sorted

Sorts tasks by name, task name will be the name of the 'it' block unless tests
are grouped togethr by at some level by a before/after all, or ordering change.
When grouped the group will be a single task named after the describe block
that defined the grouping.

=item random

Shuffles the items for a random run order.

=back

=head3 CLASS LEVEL

Specify the ordering at use time:

    use Method::Workflow::SPEC ':random';
    use Method::Workflow::SPEC ':ordered';
    use Method::Workflow::SPEC ':sorted';

=head3 ELEMENT LEVEL

Specify in the parameters list '( ... )':

    describe random_describe ( random => 1 ) { ... }

    describe sorted_describe ( sorted => 1 ) { ... }

    describe ordered_describe ( ordered => 1 ) { ... }

=head1 FENNEC PROJECT

This module is part of the Fennec project. See L<Fennec> for more details.
Fennec is a project to develop an extendable and powerful testing framework.
Together the tools that make up the Fennec framework provide a potent testing
environment.

The tools provided by Fennec are also useful on their own. Sometimes a tool
created for Fennec is useful outside the greator framework. Such tools are
turned into their own projects. This is one such project.

=over 2

=item L<Fennec> - The core framework

The primary Fennec project that ties them all together.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Method-Workflow-SPEC is free software; Standard perl licence.

Method-Workflow-SPEC is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.
