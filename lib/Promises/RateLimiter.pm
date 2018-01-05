package Promises::RateLimiter;
use strict;
use Moo;
use Algorithm::TokenBucket;
use AnyEvent;

use vars qw($VERSION);
$VERSION = '0.01';

=head1 NAME

Promises::RateLimiter - rate limit paths through promises

=head1 SYNOPSIS

This is the synopsis of L<Promises>, but with added limiting
of the number of simulatneous HTTP requests and the rate at which
requests are made to the server.

    use AnyEvent::HTTP;
    use JSON::XS qw[ decode_json ];
    use Promises qw[ collect deferred ];
    use Promises::RateLimiter;

    my $concurrent_http_requests = Promises::RateLimiter->new(
        maximum => 4,
        rate => 30/60, # 30 requests/minute
    );

    sub fetch_it {
          my ($uri) = @_;
          my $d = deferred;
          http_get $uri => sub {
              my ($body, $headers) = @_;
              $headers->{Status} == 200
                  ? $d->resolve( $uri, $body )
                  : $d->reject( $body )
          };
          $d->promise;
    }


    my @urls = (@ARGV);
    while(@urls) {

      my $cv = AnyEvent->condvar;
      
      my @limited_urls = map {
          map {
              # Wrap each URL in a Promise
              my $p = deferred;
              $p->resolve( $uri );
              $p->promise
              ->limit( $concurrent_http_requests )
          }
      } splice @urls;

      my @fetch = map {
          $_->limit( $concurrent_http_requests )
          ->then( sub { 
              my( $url ) = @_;
              fetch_it($_)
          })
          ->then( sub {
              my($url, $html) = @_;
              
              my @newly_found = extract_urls($html);
              
              push @urls, @newly_found;
              
              return $url, $html;
          })
      } @now_fetching;

      # Wait until all requests have either died or returned.
      my $done = collect( @fetch );
      
      my @retrieved = await( $done );
      ...
    }

=cut

with 'Role::RateLimiter';

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

=head1 DRAWBACKS

Currently, the limiter sends the promise to sleep until at least one
promise can continue. This produces a thundering herd effect as all
outstanding promises will wake up and retry at the same time but only
one will likely succeed. See
L<Promises::RateLimiter::Backoff> for a way to mitigate that.

Maybe Promises::RateLimiter::Backoff should become the default
strategy to prevent thundering herds.

=cut

package Promises::RateLimiter::Backoff;
use strict;
use Moo;
use Algorithm::TokenBucket;
use AnyEvent;
extends 'Promises::RateLimiter';

=head1 NAME

Promises::RateLimiter::Backoff - rate limit with larger retry spread

=head1 Strategy

This limiter counts how many attempts were already limited and schedules
the current promise to retry linearly after all previous promises will
have retried.

No exponential backoff is tried.

=cut

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
        $self->blocked( $self->blocked( -1 ));
        $self->token_bucket->count(1);
        #warn "Resolving to @$args";
        $p->resolve(@$args);
    }
}

package Promises::Deferred;
use strict;
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