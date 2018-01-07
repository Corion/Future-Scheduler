package Future::Scheduler::Mojo;
use strict;
use Moo 2;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Future::Mojo;

our $VERSION = '0.01';

sub future( $self ) {
    Future::Mojo->new
}

=head2 C<< $sched->sleep( $seconds ) >>

    $sched->sleep( 10 )->get; # wait for 10 seconds

Returns a Future that will be resolved in the number of seconds given.

=cut

sub sleep( $self, $seconds = 0 ) {
    Future::Mojo->new_timer( $seconds )
}

sub schedule( $self ) {
    Future::Mojo->new_timer( 0 )
}

1;

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
