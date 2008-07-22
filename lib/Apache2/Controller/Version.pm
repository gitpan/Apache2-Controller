package Apache2::Controller::Version;

=head1 NAME

Apache2::Controller::Version - $VERSION of Apache2::Controller

=head1 VERSION

Version 0.101.110 - BETA TESTING (ALPHA?)

=cut

use strict;
use warnings FATAL => 'all';

use base qw(Exporter);

our @EXPORT = qw($VERSION);

use version;
our $VERSION = version->new('0.101.110');

=head1 DESCRIPTION

This exports $VERSION to Apache2::Controller distribution modules.

=head1 SEE ALSO

L<Apache2::Controller>

=head1 AUTHOR

Mark Hedges, C<hedges +(a t)- scriptdolphin.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Mark Hedges.  CPAN: markle

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;
