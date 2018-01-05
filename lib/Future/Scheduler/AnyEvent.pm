package Future::Scheduler::AnyEvent;
use strict;
use Moo 2;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use AnyEvent::Future;

sub sleep( $self, $seconds = 0 ) {
    # At least until we have the backends that implement sleeping
    AnyEvent::Future->new_delay( after => $seconds );
}

sub future( $self ) {
    # At least until we have the backends that implement sleeping
    AnyEvent::Future->new;
}

sub schedule( $self ) {
    AnyEvent::Future->new_delay( after => 0 );
}

1;