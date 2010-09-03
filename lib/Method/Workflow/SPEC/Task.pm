package Method::Workflow::SPEC::Task;
use strict;
use warnings;

use Method::Workflow::Meta qw/ meta_for /;
use Method::Workflow qw/ accessors /;
use Scalar::Util qw/ blessed /;
use List::Util qw/ shuffle /;
use aliased 'Method::Workflow::SPEC';

my @ARRAY_ACCESSORS = qw/ before_each after_each before_all after_all subtasks /;

accessors qw/ describe _root _ordering it /, map { "${_}_ref" } @ARRAY_ACCESSORS;

for my $accessor ( @ARRAY_ACCESSORS ) {
    my $ref = "${accessor}_ref";
    my $sub = sub {
        my $self = shift;
        my $list = $self->$ref;
        unless ( $list ) {
            $list = [];
            $self->$ref($list);
        }
        push @$list => @_;
        return @$list;
    };
    no strict 'refs';
    *$accessor = $sub;
}

sub new {
    my $class = shift;
    my %proto = @_;
    return bless( \%proto, $class );
}

sub name {
    my $self = shift;
    return $self->it->name
        if $self->it;

    return $self->describe->name
        if $self->describe;

    return 'un-named';
}

sub set_order_unless_set {
    my ( $self, $order ) = @_;
    return if $self->_ordering;
    $self->_ordering( $order );
    $_->set_order_unless_set( $order )
        for $self->subtasks;
}

sub add_subtasks {
    my $self = shift;
    push @{ $self->subtasks_ref } => @_;
    if ( $self->_ordering ) {
        $_->set_order_unless_set( $self->_ordering )
            for @_;
    }
}

sub ordering {
    my $self = shift;
    return $self->_ordering()
        if $self->_ordering();

    my $root = $self->_root;
    my $specs = meta_for( SPEC )->prop( blessed( $root ) || $root );
    my ($order) = grep { $specs->{$_} }
        @Method::Workflow::SPEC::ORDER;

    return $order || 'ordered'
}

sub run_task {
    my $self = shift;
    my ( $root ) = @_;
    my @out;

    $self->_root( $root );
    $self->run_before_alls;

    if ( $self->it ) {
        $self->run_before_each;
        push @out => $self->run_it;
        $self->run_after_each;
    }

    push @out => $self->run_subtasks;
    $self->run_after_alls;
    $self->_root( undef );

    return @out;
}

sub run_before_alls {
    my $self = shift;
    $_->run_workflow( $self->_root )
        for $self->before_all;
}

sub run_after_alls {
    my $self = shift;
    $_->run_workflow( $self->_root )
        for reverse $self->after_all;
}

sub run_before_each {
    my $self = shift;
    $_->run_workflow( $self->_root )
        for $self->before_each;
}

sub run_after_each {
    my $self = shift;
    $_->run_workflow( $self->_root )
        for reverse $self->after_each;
}

sub run_it {
    my $self = shift;
    $self->it->run_workflow( $self->_root );
}

sub run_subtasks {
    my $self = shift;

    my @list = $self->subtasks;

    @list = sort { $a->name cmp $b->name } @list
        if $self->ordering eq 'sorted';

    @list = shuffle @list if $self->ordering eq 'random';

    $_->run_task( $self->_root )
        for @list
}

1;
