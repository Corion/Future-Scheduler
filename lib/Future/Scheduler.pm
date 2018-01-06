package Future::Scheduler;
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

=head1 NAME

Future::Scheduler - provide helper functions for Future

=head1 SYNOPSIS

    my $sched = Future::Scheduler->new();
    my $wakeup = $sched->sleep(5);
    $wakeup->then(...)->get;

This module is a wrapper around the various backend of Future providing
a common API for the simple scheduling mechanisms available from the IO loops.

=head2 Supported event loops

Currently only L<AnyEvent>, L<Mojolicious> and L<IO::Async> are supported.

=cut

our $implementation;
our $VERSION = '0.01';

our @loops = (
    ['IO/Async/Loop.pm' => 'Future::Scheduler::IOAsync' ],
    ['Mojo/IOLoop.pm'   => 'Future::Scheduler::Mojo' ],
    ['AnyEvent.pm'      => 'Future::Scheduler::AnyEvent'],
    ['AE.pm'            => 'Future::Scheduler::AnyEvent'],
    # IO::Async support would be nice
    
    # The fallback, will always catch due to loading Future itself
    ['Future.pm' => 'Future::Scheduler::Future'],
);

=head1 METHODS

=head2 C<< Future::Scheduler->new() >>

    my $ua = Future::Scheduler->new();

Creates a new instance of the scheduler abstraction.

=cut

sub new($factoryclass, @args) {
    $implementation ||= $factoryclass->best_implementation();
    
    # return a new instance
    $implementation->new(@args);
}

sub best_implementation( $class, @candidates ) {
    
    if(! @candidates) {
        @candidates = @loops;
    };

    # Find the currently running/loaded event loop(s)
    #use Data::Dumper;
    #warn Dumper \%INC;
    #warn Dumper \@candidates;
    my @applicable_implementations = map {
        $_->[1]
    } grep {
        $INC{$_->[0]}
    } @candidates;
    
    # Check which one we can load:
    for my $impl (@applicable_implementations) {
        if( eval "require $impl; 1" ) {
            return $impl;
        };
    };
};

=head2 C<< $scheduler->sleep($seconds) >>

    ...

=head2 C<< $scheduler->schedule() >>

    ...

Schedules a Future to be executed from the top level mainloop. This is usually
equivalent to C<< ->sleep(0) >>.

=head1 SEE ALSO

L<Future>

=head1 REPOSITORY

The public repository of this module is 
L<http://github.com/Corion/...>.

=head1 SUPPORT

The public support forum of this module is
L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=...>
or via mail to L<future-http-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2018 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;