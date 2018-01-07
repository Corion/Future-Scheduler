package Future::Scheduler::Functions;
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Exporter 'import';
use Future::Scheduler;

our @EXPORT_OK = qw(sleep schedule future);
our $VERSION = '0.01';

=head1 NAME

Future::Scheduler::Functions - provide helper functions for Future

=head1 SYNOPSIS

    use Future::Scheduler::Functions( sleep schedule );
    my $wakeup = sleep(5);
    $wakeup->then(...)->get;

This module is a wrapper around the various backend of Future providing
a common API for the simple scheduling mechanisms available from the IO loops.
Instead of supplying an object, it exports the functions. This gives you less
control over the backend used, but also removes the need to store
an object.

=cut

our $scheduler;
sub get_scheduler {
    $scheduler ||= Future::Scheduler->new();
}

sub future {
    get_scheduler->future( @_ )
}

sub sleep {
    get_scheduler->sleep( @_ )
}

sub schedule {
    get_scheduler->schedule( @_ )
}

=head1 SEE ALSO

L<Future::Scheduler>

=head1 REPOSITORY

The public repository of this module is
L<http://github.com/Corion/Future-Scheduler>.

=head1 SUPPORT

The public support forum of this module is
L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Future-Scheduler>
or via mail to L<future-scheduler-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2018 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;