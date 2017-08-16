package Role::RateLimiter;
use strict;
use Moo::Role;
use Algorithm::TokenBucket;

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

1;