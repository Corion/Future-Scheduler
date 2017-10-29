package RateLimiter::Bucket;
use strict;
use Moo;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use Algorithm::TokenBucket;
use AnyEvent::Future; # later we'll go independent
use Scalar::Util qw(weaken);

has burst => (
    is => 'ro',
    default => 5,
);

has rate => (
    is => 'ro',
    default => 1,
);

# Hmm - these need to go elsewhere, as they are not rate-limiting
# but parallelism-limiting
has maximum => (
    is => 'rw',
    default => 4,
);

has active_count => (
    is => 'rw',
    default => 0,
);

# The callback that gets executed when ->maximum is reached
has on_highwater => (
    is => 'rw',
);

has bucket => (
    is => 'lazy',
    default => sub( $self ) { Algorithm::TokenBucket->new( $self->{ rate }, $self->{ burst }) },
);

has queue => (
    is => 'lazy',
    default => sub { [] },
);

# The future that will be used to ->sleep()
has next_token_available => (
    is => 'rw',
);

# XXX parallelism-limiting
# For a semaphore-style lock
sub get_release_token( $self ) {
    # Returns a token for housekeeping
    # The housekeeping callback may or may not trigger more futures
    # to be executed
    my $token_released = guard {
        #warn "Reducing active count to $c";
        $self->remove_active();
        # scan the queue and execute the next future
        if( my $next = shift @{ $self->queue }) {
            #my( $future, $args ) = @$next;
            $self->add_active()->then(sub( $token ) {
                $next->done( $token );
            })->get;
            # XXX Why do we want the ->get here?! How else can we
            # prevent losing our ->add_active future?
        };
    };
}

sub add_active( $self ) {
    if( $self->active_count < $self->maximum ) {
        $self->active_count( $self->active_count+1 );
        return $self->future->done($self->get_release_token);
    } else {
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

sub limit( $self, $key=undef ) {
    my $token = undef;
    my $res = $self->future;
    #warn "Storing $res";
    push @{ $self->queue }, [ $res, $token ];
    $self->schedule_queued;
    $res;
}

=head2 C<< $bucket->schedule_queued >>

  $bucket->schedule_queued

Processes all futures that can be started while obeying the current rate limits
(including burst).
  
=cut

sub schedule_queued( $self ) {
    my $bucket = $self->bucket;
    my $queue = $self->queue;
    while( @$queue and $bucket->conform(1)) {
        #warn "Dispatching";
        my( $f, $args ) = @{ shift @$queue };
        $bucket->count(1);
        $self->schedule( $f, $args );
    };
    if( 0+@$queue ) {
        # We have some more to launch but reached our rate limit
        # so we now schedule a callback to ourselves (if we haven't already)
        if( ! $self->next_token_available ) {
            my $earliest_time = $bucket->until(1);
            my $s = $self;
            weaken $s;
            #warn "Setting up cb after $earliest_time";
            my $wakeup;
            $wakeup = $self->sleep($earliest_time)->then(sub{
                $wakeup->set_label('wakeup call');
                # Remove this callback:
                $self->next_token_available(undef);
                $s->schedule_queued();
                Future->done()
            })->catch( sub {
                use Data::Dumper;
                warn "Caught error: $@";
                warn Dumper \@_;
            });
            $self->next_token_available($wakeup);
        };
    };
}

1;