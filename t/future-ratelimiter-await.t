#!perl -w
use strict;
use Test::More tests => 1;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Future;
use AnyEvent::Future;
use Future::AsyncAwait;
use RateLimiter::Bucket;
use Data::Dumper;

my $limiter = RateLimiter::Bucket->new(
    burst => 5,
    rate  => 30/60, # 0.5/s
);

async sub limit_test {
    my( $j ) = @_;
    my $l = $limiter->limit;
    my $token = await $l;
    diag "$j done\n";
    return Future->done($j);
};

my $started = time;
my @elements = Future->wait_all( map {
        limit_test( $_ );
} 1..10)->get;
#@elements = sort { $a<=>$b } map { $_->get } @elements;
@elements = map { $_->get } @elements;
is_deeply( \@elements, [1..10], "We get the expected results, in order")
    or diag Dumper \@elements;