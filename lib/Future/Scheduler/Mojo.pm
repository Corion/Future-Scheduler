package Future::Scheduler::Mojo;
use strict;
use Moo 2;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Future::Mojo;

sub future( $self ) {
    Future::Mojo->new
}

=head2 C<< $sched->sleep( $seconds ) >>

    $sched->sleep( 10 )->get; # wait for 10 seconds

Returns a Future that will be resolved in the number of seconds given.

=cut

sub sleep( $self, $seconds = 0 ) {
    Future::Mojo->new_timer( $seconds )
}

sub schedule( $self ) {
    Future::Mojo->new_timer( 0 )
}

1;