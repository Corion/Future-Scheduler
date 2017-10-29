package Role::RateLimiter;
use strict;
use Moo::Role;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use RateLimiter::Bucket;

# Container for the defaults

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

has 'buckets' => (
    is => 'lazy',
    default => sub { {} },
);

sub _make_bucket( $self, %options ) {
    $options{ rate } ||= $self->rate;
    $options{ maximum } ||= $self->maximum;
    $options{ burst } ||= $self->burst;
    RateLimiter::Bucket->new( \%options )
}

sub _bucket( $self, $key ) {
    $key = '' unless defined $key;
    $self->buckets->{ $key } ||= $self->_make_bucket;
}

1;