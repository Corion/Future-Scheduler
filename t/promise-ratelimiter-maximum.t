#!perl -w
use strict;
use Test::More tests => 1;
use Promises backend => ['AnyEvent'], 'deferred', 'collect';
use Promises::RateLimiter;
use Data::Dumper;

my $limiter = Promises::RateLimiter->new(
    burst => 5,
    rate  => 20/60, # 3/s
    maximum => 2,
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

my %active;
my $active_max = 0;

sub delayed_result {
    my @res = @_;
    my $done = deferred;
    my $t; $t = AnyEvent->timer( after => rand(1), cb => sub {
        undef $t;
        $done->resolve(@res);
    });
    $done->promise
}

my @elements = await collect( map {
    my $i = $_;
    my $p = delayed_result( $i );
    $p->limit($limiter)
      ->then(sub{
          my($i) = @_;
          $active{ $i } = 1;
          return delayed_result( $i );
      })
      ->then(sub {
          my($i) = @_;
          my $current_active = () = keys %active;
          $active_max = $current_active > $active_max ? $current_active : $active_max;
          delete $active{ $i };
          diag sprintf "%d done, %d active\n", $i, $current_active;
          return $i;
      });
} 1..10);
@elements = sort { $a<=>$b } map { @$_ } @elements;
is_deeply( \@elements, [1..10], "We get the expected results")
    or diag Dumper \@elements;
cmp_ok $active_max, '<=', 2,
    "No more than 2 jobs active at the same time"; 