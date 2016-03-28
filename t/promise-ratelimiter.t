#!perl -w
use strict;
use Test::More tests => 1;
use Promises backend => ['AnyEvent'], 'deferred', 'collect';
use Promises::RateLimiter;
use Data::Dumper;

my $limiter = Promises::RateLimiter::Backoff->new(
    burst => 5,
    rate  => 30/60, # 2/s
);

sub await($) {
    my $promise = $_[0];
    my @res;
    if( $promise->is_unfulfilled ) {
        require AnyEvent;
        my $await = AnyEvent->condvar;
        $promise->then(sub{ $await->send(@_)});
        @res = $await->recv;
    } else {
        @res = @{ $promise->result }
    }
    @res
};

my $started = time;
my @elements = await collect( map {
    my $i = $_;
    my $p = deferred;
    $p->resolve($i);
    $p->limit($limiter)
      ->then(sub{
          my($i) = @_;
          print "$i done\n";
          return $i;
      });
} 1..10);
@elements = sort { $a<=>$b } map { @$_ } @elements;
is_deeply( \@elements, [1..10], "We get the expected results")
    or diag Dumper \@elements;