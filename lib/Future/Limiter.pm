package Future::Limiter;
use strict;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use Carp qw(croak);

use Future::Limiter::Resource;
use Future::Limiter::Rate;

=head1 NAME

Future::Limiter - impose rate and resource limits

=head1 SYNOPSIS

  # rate of 30 per minute
  my $limiter = Future::Limiter->new(
      rate  => 0.5,
      burst => 2,
  );

  $limiter->limit( $hostname, $url )->then(sub {
      my( $token, $url ) = @_;
      request_url( $url )
  })->then(sub {
      ...
  });

This module provides an API to handle rate limits and resource limits in a
unified API.

=cut

# Container for the defaults

has bucket_class => (
    is => 'ro',
);

has bucket_args => (
    is => 'ro',
    default => sub { {} },
);

has 'buckets' => (
    is => 'lazy',
    default => sub { {} },
);

sub _make_bucket( $self, %options ) {
    %options = (%{ $self->bucket_args() }, %options);
    $self->bucket_class->new( \%options );
}

sub _bucket( $self, $key ) {
    $key = '' unless defined $key;
    $self->buckets->{ $key } ||= $self->_make_bucket;
}

around 'BUILDARGS' => sub ( $orig, $class, @args ) {
    my %args;
    if( ref $args[0] ) {
        %args = ${ $args[0] }
    } else {
        %args = @args
    };
    my $bucket_class = delete $args{ bucket_class };
    if( exists $args{ maximum }) {
        $bucket_class ||= 'Future::Limiter::Resource';
    } elsif( exists $args{ rate } or exists $args{ burst }) {
        $bucket_class ||= 'Future::Limiter::Rate';
    } else {
        require Data::Dumper;
        croak "Don't know what to do with " . Data::Dumper::Dumper \%args;
    }
    $class->$orig( bucket_class => $bucket_class, bucket_args => \%args )
};

=head2 C<< $l->limit( $key, @args ) >>

  my $token;
  $l->limit( $key )->then( sub {
      $token = @_;
      
      ... return another Future
  })->then(sub {
  
      # release the token to release our limiting
      undef $token
  })

This method returns a L<Future> that will become fulfilled if the current
limit is not reached. The C<$key> parameter restricts that resource to a
specific key (like, a hostname).

The future returns a token that must be released for the resource to be freed
again. Additional parameters are passed through as well.

=cut

sub limit( $self, $key = undef, @args ) {
    return $self->_bucket( $key )->limit( @args );

}
1;