LinkChecker:
#!perl -w
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Getopt::Long;
use Pod::Usage;
use Future::HTTP;
use RateLimiter::Bucket;
use URI;

GetOptions(
    'host-connection-limit:i' => \my $host_connection_limit,
    'connection-limit:i' => \my $connection_limit,
    'timeout:i' => \my $timeout,
) or pod2usage(2);
$host_connection_limit ||= 9999;
$connection_limit ||= 9999;

my $per_host = Future::Limiter( maximum => $host_connection_limit, );
my $total    = Future::Limiter( maximum => $connection_limit );

my $request_rate = 600 / 60; # Limit to 10 requests per second

my %status; # maybe tie it to disk for persistence
# exists but undef: queued but unchecked
# exists but false: requested
# exists and true: status

my @queue;

for my $start_url ( @ARGV ) {
    push @queue, URI->new($start_url);
};
my %requested;
my %outstanding;

# Should we turn all of this into one Future?!
while( my $url = shift @queue or keys %outstanding) {
    if( $url ) {
        # Do rate-limiting here
        my $host_token;
        my $total_token;
        $outstanding{ $url } = $total->limit()->then( sub( $t ) {
            $total_token = $t;
            fetch_url( $url )
        })->then(sub( $body, $headers ) {
            my $h = $url->host;
            $per_host->limit( $h, $body, $headers)
        })->then( sub( $t, $body, $headers ) {
            $host_token = $t;
            delete $outstanding{ $url };
            $status{ $url } = $headers->{Status};
            push @queue, grep { !$requested{$_}++ } get_links( $body );
        })->on_ready(sub {
            # Clean up our tokens
            undef $host_token;
            undef $total_token;
        });
    } elsif( !@queue ) {
        # Spin, waiting for something to happen
        Future->wait_any( values %outstanding )->get;
    };
}

