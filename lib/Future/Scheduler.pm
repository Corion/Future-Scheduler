package Future::Scheduler;
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Future;

=head1 NAME

Future::Scheduler - provide helper functions for Future

=head1 SYNOPSIS

    my $sched = Future::Scheduler->new();
    my $wakeup = $sched->sleep(5);
    $wakeup->then(...)->get;

This module is a wrapper around the various backends of Future providing
a common API for the simple scheduling mechanisms available from the IO loops.

=head2 Supported event loops

Currently only L<AnyEvent>, L<Mojolicious> and L<IO::Async> are supported
in addition to a trivial, blocking default backend if none of the above event
loops can be detected.

=cut

our $implementation;
our $VERSION = '0.01';

our @loops = (
    ['IO/Async.pm'      => 'Future::Scheduler::IOAsync' ],
    ['Mojo/IOLoop.pm'   => 'Future::Scheduler::Mojo' ],
    ['AnyEvent.pm'      => 'Future::Scheduler::AnyEvent'],
    ['AE.pm'            => 'Future::Scheduler::AnyEvent'],

    # The fallback, will always catch due to loading Future itself
    ['Future.pm'        => 'Future::Scheduler::Future'],
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

    if( ! @applicable_implementations ) {
        require Data::Dumper;
        warn Data::Dumper::Dumper( \%INC );
        die "No suitable implementation found in " . Data::Dumper::Dumper(\@candidates);
    };

    # Check which one we can load:
    my @errors;
    for my $impl (@applicable_implementations) {
        if( eval "require $impl; 1" ) {
            return $impl;
        } else {
            push @errors, [$impl, "$@"];
        }
    };

    # If we get here, we didn't find a suitable implementation
    require Data::Dumper;
    warn Data::Dumper::Dumper( \%INC );
    die "No working/loadable implementation found:\n" . Data::Dumper::Dumper(\@errors);
};

=head2 C<< $scheduler->sleep($seconds) >>

    my $wakeup = $scheduler->sleep( 5 );
    $wakeup->then(sub {
        print "It's now 5 seconds later\n";
    });

Returns a future that will be fulfilled after C<$seconds> seconds. Depending on
the backend features, subsecond resoultion might be available.

=head2 C<< $scheduler->schedule() >>

    $scheduler->schedule()->then(sub {
    });

Schedules a Future to be executed from the top level mainloop. This is usually
equivalent to C<< ->sleep(0) >>. This is convenient if you want to prevent the
call stack getting too deep, but makes it much harder to find where a Future
originated, due to losing the callstack.

See also L<Tracing Methods in Future|Future/TRACING> for how to give your Futures names.

=head1 VARIABLES

=head2 C<< @Future::Scheduler::loops >>

This is the list of adapter implementations for the various backends. If you
have another backend that is not yet supported by L<Future::Scheduler>, you
can C<unshift> it to the list yourself as a workaround.

The array holds the pairs of

    [ "loaded/module.pm" => 'Backend::Implementation::Class' ],

=head2 C<< $Future::Scheduler::implementation >>

Holds the base class that provides the current implementation. This is
initialized through

  $Future::Scheduler::implementation = Future::Scheduler->best_implementation()

If you really, really need to force a specific implementation rather than
letting the module autodetect it, you can set it yourself.

=head1 SEE ALSO

L<Future>

=head1 REPOSITORY

The public repository of this module is
L<http://github.com/Corion/Future-Scheduler>.

=head1 SUPPORT

The public support forum of this module is
L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Future-Scheduler>
or via mail to L<future-scheduler-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2018 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;