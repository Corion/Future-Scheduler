package Future::RateLimiter;
use strict;
use Moo 2;
with 'Role::RateLimiter';

has waiting => (
    is => 'lazy',
    default => sub {[]},
);

use Scalar::Util 'weaken';

use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

=head1 NAME

Future::RateLimiter - rate-limits your futures

=head1 SYNOPSIS

Actually, this is more about resource control in general than just
rate limiting.

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

=head1 IMPLEMENTING SLEEP

 delay_class => 'AnyEvent::Future'
 delay_deferred => sub {...}

=head1 PATTERNS

=head2 Waiting some time to rate limit

  my $limiter = Algorithm::TokenBucket->new( 10, 3 );

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
      (my $token) = await $single->limit();
      ...
      undef $token; # Allow access to others again
  }

=head2 Serializing access with a user-defined string token
  
  $l->limit([@_], token => 'foo');
  ...
  $l->release(token => 'foo'); # Allow access to others again
  
=head1 METHODS

=head2 C<< ->limit( $args, %options )

  $l->limit([@_])->then( sub {
      my($token, @args) = @_;
      ...
  });

Apply a limit for a resource

  $l->limit([@_], key => $url->host)->then( sub {
      my($token, @args) = @_;
      ...
  });

=cut

sub limit( $self, $args=[], %options ) {
    my $bucket = $self->_bucket( $options{ key });
    $bucket->limit( $args );
}

# Role Sleeper::AnyEvent
sub sleep( $self, $s = 1 ) {
    AnyEvent::Future->new_delay(after => $s)->on_ready(sub {
        warn "Timer expired";
    });
}

sub future( $self ) {
    AnyEvent::Future->new
}

1;

=head1 SEE ALSO

More limiters, collected by Thomas Fahle

L<Algorithm::TokenBucket> - Token bucket rate limiting algorithm


L<Algorithm::FloodControl> - Limit event processing to count/time ratio.

L<https://www.perl.com/pub/2004/11/11/floodcontrol.html>


L<Object::RateLimiter> - A flood control (rate limiter) object

L<Algorithm::LeakyBucket> - Perl implementation of leaky bucket rate limiting

L<Sub::Throttler> - Rate limit sync and async function calls

L<Data::Throttler> - Limit data throughput


=cut