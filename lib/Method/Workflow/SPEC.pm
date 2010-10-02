package Method::Workflow::SPEC;
use strict;
use warnings;

use Method::Workflow ();
use Method::Workflow::SubClass;
use Devel::Declare::Parser::Fennec;
use Try::Tiny;
use Exodist::Util qw/
    alias
    blessed
    accessors
    array_accessors
/;

our $VERSION = '0.201';

alias qw/
    Method::Workflow
    Method::Workflow::SPEC::It
    Method::Workflow::SPEC::BeforeEach
    Method::Workflow::SPEC::AfterEach
    Method::Workflow::SPEC::BeforeAll
    Method::Workflow::SPEC::AfterAll
    Method::Workflow::SPEC::Task
/;

sub after_import {
    my $class = shift;
    my ( $caller, $specs ) = @_;
    Workflow->after_import( $caller, $specs );
    $_->export_to( $caller ) for Workflow, It, BeforeEach, AfterEach, BeforeAll, AfterAll;
}

keyword 'describe';

accessors qw/parent_task/;
array_accessors qw/before after result_tasks/;

sub pre_child_run_hook {
    my $self = shift;
    my ( $invocant, $result ) = @_;
    my @tasks;


    # Pull all before/after/it items from meta
    my @before_each =         $self->pull_children( BeforeEach  );
    my @before_all  =         $self->pull_children( BeforeAll   );
    my @it          =         $self->pull_children( It          );
    my @describe    =         $self->children(      __PACKAGE__ );
    #
    my @after_each_ordered = $self->pull_children( AfterEach   );
    my @after_each = reverse @after_each_ordered;
    my @after_all  = reverse $self->pull_children( AfterAll    );

    for my $it ( @it ) {
        push @tasks => Task->new(
            it     => $it,
            before_ref => \@before_each,
            after_ref => \@after_each,
            $self->ordering
                ? ( $self->ordering => 1 )
                : (),
            $self->parent_ordering
                ? ( parent_ordering => $self->parent_ordering )
                : (),
        );
    }

    # Create a root task if there are before/after alls
    # - Root should also have ordering if necessary
    if ( @tasks && ( @before_all || @after_all )) {
        my $parent = Task->new(
            subtasks_ref => \@tasks,
            before_ref => \@before_all,
            after_ref => \@after_all,
            $self->ordering
                ? ( $self->ordering => 1 )
                : (),
            $self->parent_ordering
                ? ( parent_ordering => $self->parent_ordering )
                : (),
        );
        $self->parent_task( $parent );
        $self->result_tasks_ref( $result->tasks_ref );
        $result->tasks_ref( \@tasks );
    }
    elsif ( @tasks ) {
        $result->push_tasks( @tasks );
    }

    for my $child ( @describe ) {
        $child->push_children( @before_each, @after_each_ordered );
    }
}

sub post_child_run_hook {
    my $self = shift;
    my ( $invocant, $result ) = @_;
    my $parent = $self->parent_task;
    return unless $parent;

    $result->tasks_ref( $self->result_tasks_ref );
    $self->result_tasks_ref([]);
    $result->push_tasks( $parent );
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

    our @RUN_ORDER;

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

=head2 ORDERING TASKS

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
