package Future::Limiter::Role;
use Moo::Role;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use Future::Scheduler;

has 'scheduler' => (
    is => 'lazy',
    default => sub { Future::Scheduler->new() }
);

sub future( $self ) {
    $self->scheduler->future()
}

sub sleep( $self, $seconds = 0 ) {
    $self->scheduler->sleep($seconds)
}

sub schedule( $self, $f, $args=[], $seconds = 0 ) {
    # This is backend-specific and should put a timeout
    # after 0 ms into the queue or however the IO loop schedules
    # an immediate callback from the IO loop
    my $n;
    $n = $self->sleep($seconds)->then(sub { undef $n; $f->done( @$args ) });
    $n
}

sub limit( $self, $key=undef, @args ) {
    my $token = undef;
    my $res = $self->future;
    push @{ $self->queue }, [ $res, $token, \@args ];
    $self->schedule_queued;
    $res;
}

1;