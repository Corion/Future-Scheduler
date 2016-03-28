package Promises::RateLimiter;
use strict;
use Moo;
use Algorithm::TokenBucket;
use AnyEvent;

has token_bucket => (
    is => 'lazy',
    default => sub { Algorithm::TokenBucket->new( $_[0]->rate, $_[0]->burst ) },
);

has burst => (
    is => 'ro',
    default => 5,
);

has rate => (
    is => 'ro',
    default => 1,
);

has maximum => (
    is => 'rw',
    default => 4,
);

has active_count => (
    is => 'rw',
    default => 0,
);

sub retry {
    my($self,$p,$args) = @_;
    if(!$self->token_bucket->conform(1) or $self->active_count >= $self->maximum) {
        my $until = $self->token_bucket->until(1);
        if( ! $until ) {
            #warn sprintf "Maximum concurrency hit (%d)", $self->maximum;
            $until = 1;
        };
        #warn "@$args Waiting $until seconds";
        my $timer; $timer = AnyEvent->timer(after => $until, cb => sub {
            undef $timer;
            $self->retry($p,$args);
        });
    } else {
        $self->token_bucket->count(1);
        
        # Keep time how long the average item takes
        # and use that as the average wait time above
        my $start_time= time;
        $self->active_count( $self->active_count +1 );
        $p->finally(sub {
            $self->active_count( $self->active_count -1 );
        });
        $p->resolve(@$args);
    }
}

sub limit {
    my( $self, $promise ) = @_;
    $promise->then(sub {
        # This is slightly inefficient, as we always construct
        # one more intermediate Promise, but it makes the code
        # so much simpler by eliminating lots of code repetition

        my @args = @_;
    
        my $results = Promises::deferred;
        $self->retry($results,\@args);
        return $results;
    })
}

package Promises::RateLimiter::Backoff;
use strict;
use Moo;
use Algorithm::TokenBucket;
use AnyEvent;
extends 'Promises::RateLimiter';

has backoff => (
    is => 'ro',
    default => 2,
);

has blocked => (
    is => 'rw',
    default => 0,
);

#use Data::Dumper;
sub retry {
    my($self,$p,$args) = @_;
    if(!$self->token_bucket->conform(1) ) {
        my $until = $self->token_bucket->until(1);
        $until += $self->blocked * $self->rate;
        #warn "@$args Waiting $until seconds";
        $self->blocked( $self->blocked+1 );
        my $timer; $timer = AnyEvent->timer(after => $until, cb => sub {
            undef $timer;
            $self->retry($p,$args);
        });
    } else {
        #warn "Using token";
        $self->blocked( 0 );
        $self->token_bucket->count(1);
        #warn "Resolving to @$args";
        $p->resolve(@$args);
    }
}

package Promises::Deferred;
# Yay monkey patch

sub limit {
    my( $deferred, $limiter ) = @_;
    $limiter->limit($deferred);
}

package Promises::Promise;
# Yay monkey patch

sub limit {
    my( $deferred, $limiter ) = @_;
    $limiter->limit($deferred);
}

1;