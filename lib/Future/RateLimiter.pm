package Future::RateLimiter;
use strict;
use Moo 2;
with 'Role::RateLimiter';

use Scalar::Util 'weaken';

use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use Guard 'guard';

=head1 NAME

Future::RateLimiter - rate-limits your futures

=head1 SYNOPSIS

  my $l = Future::RateLimiter->new(
      ...
  );

  sub foo {
      my( $f ) = @_;
      $l->limit('foo')->then( $f );
  }

Inline limiting

  $f->then( sub {
      ...
  })
  ->then( sub {
      $l->limit('foo', [@_]);
  })
  ->then( sub {
      ...
  });


Using L<Async::Await> style

  async sub foo {
      ...
      await $l->limit('foo');
      $f
      ...
  }

=head1 PATTERNS

=head2 Waiting some time to rate limit

  my $Limiter = Algorithm::TokenBucket->new( 10, 3 );

  ...
  while( my $sleep = $limiter->take( 1 )) {
      ... do work ...
  } else {
      my $sleep = $limiter->until(1);
      sleep $sleep;
  }
  ...

becomes

  my $limiter = Future::RateLimiter->new( 10, 3 );

  ...
  await $limiter->limit();
  ...

=head2 Serializing access to a resource

  my $single = Future::RateLimiter->new( maximum => 1 );


  sub save_file {
      my $token = await $single->limit();
      ...
      undef $token; # Allow access to others again
  }

=cut

sub limit( $self, $args=[], $sleeper=$self->future ) {
    if(!$self->token_bucket->conform(1) or $self->active_count >= $self->maximum) {
        my $until = $self->token_bucket->until(1);
        if( ! $until ) {
            warn sprintf "Maximum concurrency hit (%d)", $self->maximum;
            $until = 1;
        };
        #warn "@$args Waiting $until seconds";
        my $timer; $timer = $self->sleep( $until )->on_ready( sub{
            undef $timer;
            warn "@$args Timer expired";

            # Meh, how to reschedule here?
            # Refactor this block out into its own subroutine?
            $self->limit($args,$sleeper);
        });

    } else {
        $self->token_bucket->count(1);

        # Keep time how long the average item takes
        # and use that as the average wait time above
        my $start_time = time;
        # Meh - here we need the next future...
        $self->active_count( $self->active_count +1 );
        my $s = $self;
        weaken $s;
        my $token_released = guard {
            my $c = $s->active_count -1;
            warn "Reducing active count to $c";
            $s->active_count( $c );
        };
        warn "@$args resolving";
        $sleeper->done( $token_released );
    }
    return $sleeper
}

# Role Sleeper::AnyEvent
sub sleep( $self, $s = 1 ) {
    AnyEvent::Future->new_timeout(after => $s)->on_ready(sub {
        warn "Timer expired";
    });
}

sub future( $self ) {
    AnyEvent::Future->new
}

1;