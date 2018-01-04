package Future::Limiter::Resource;
use strict;
use Moo;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use AnyEvent::Future; # later we'll go independent
use Scalar::Util qw(weaken);
use Guard 'guard';

has maximum => (
    is => 'rw',
    default => 4,
);

has active_count => (
    is => 'rw',
    default => 0,
);

# The callback that gets executed when ->maximum+1 is reached
has on_highwater => (
    is => 'rw',
);

has queue => (
    is => 'lazy',
    default => sub { [] },
);

# For a semaphore-style lock
sub get_release_token( $self ) {
    # Returns a token for housekeeping
    # The housekeeping callback may or may not trigger more futures
    # to be executed
    my $token_released = guard {
        #warn "Reducing active count to $c";
        $self->remove_active();
        # scan the queue and execute the next future
        if( @{ $self->queue }) {
            $self->schedule_queued;
        };
    };
}

sub add_active( $self ) {
    if( $self->active_count < $self->maximum ) {
        $self->active_count( $self->active_count+1 );
        return $self->future->done($self->get_release_token);
    } else {
        # ?! How will this ever kick off?!
        return $self->future->new();
    }
}

sub remove_active( $self ) {
    if( $self->active_count > 0 ) {
        $self->active_count( $self->active_count-1 );
    };
}

sub schedule( $self, $f, $args=[], $seconds = 0 ) {
    # This is backend-specific and should put a timeout
    # after 0 ms into the queue or however the IO loop schedules
    # an immediate callback from the IO loop
    my $n;
    $n = $self->sleep($seconds)->then(sub { undef $n; $f->done( @$args ) });
    $n
}

=head2 C<< ->sleep >>

  $l->sleep( 10 )->then(sub {
      ...
  });

  await $l->sleep( 10 );

Returns a future that will execute in $after seconds

=cut

sub sleep( $self, $seconds = 0 ) {
    # At least until we have the backends that implement sleeping
    AnyEvent::Future->new_delay( after => $seconds );
}

sub future( $self ) {
    # At least until we have the backends that implement sleeping
    AnyEvent::Future->new;
}

=head2 C<< $bucket->enqueue( $cb, $args ) >>

  my $f = $bucket->enqueue(sub {
      my( $token, @args ) = @_;
      ...
  }, '1');

Enqueues a callback and returns a future. The callback will be passed a token
as the first parameter. Releasing that token will release the locks that the
future holds.

=cut

sub limit( $self, $key=undef, @args ) {
    my $token = undef;
    my $res = $self->future;
    push @{ $self->queue }, [ $res, $token, \@args ];
    $self->schedule_queued;
    $res;
}

=head2 C<< $bucket->schedule_queued >>

  $bucket->schedule_queued

Processes all futures that can be started while obeying the current rate limits.
  
=cut

sub schedule_queued( $self ) {
    my $queue = $self->queue;
    while( @$queue and $self->active_count < $self->maximum ) {
        #warn sprintf "Dispatching (act/max %d/%d)", $self->active_count, $self->maximum;
        my( $f, $args ) = @{ shift @$queue };
        # But ->schedule doesn't increase ->active_count, does it?!
        my $n;
        $n = $self->add_active;
        my $res; $res = $n->then(sub( $token, @args ) {
            undef $res;
            $f->done( $token, @$args )
        });
    };
    if( 0+@$queue ) {
        # We have some more to launch but reached our concurrency limit
        # the active futures will call us again in their ->on_done()
    };
}

1;