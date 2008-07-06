package Apache2::Controller::Log::DetectAbortedConnection;

# fwhew! that was a mouthful.

=head1 NAME

Apache2::Controller::Log::DetectAbortedConnection -
helper handler for detecting cancelled connections to the client.

=head1 DESCRIPTION

You don't need to use this handler.

This is pushed internally by L<Apache2::Controller::Session>
to detect in the PerlLogHandler phase if the connection has
been broken to the client before the server closes the connection.

=head1 FUNCTIONS

=head2 handler

Sets C<<$r->notes->{_a2c_connection_aborted}>> with the
boolean results of C<<$r->connection->aborted()>> and returns.

=cut

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use Apache2::RequestRec ();
use Apache2::Const -compile => qw( OK );

sub handler {
    my ($r) = @_;
    $r->notes->{connection_closed} = $r->connection->aborted();
    return Apache2::Const::OK;
}

1;

=head1 SEE ALSO

L<Apache2::Controller::Session>, 

L<Apache2::Controller>,

=head1 AUTHOR

Mark Hedges, C<< <hedges at scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

