package Method::Workflow::SPEC::BeforeAll;
use strict;
use warnings;

use Method::Workflow::SubClass;
use Carp qw/croak/;

keyword 'before_all';

sub init {
    croak shift->keyword . " can only be used within a describe {} block."
        unless parent_workflow()->isa( 'Method::Workflow::SPEC' );
}

1;

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
