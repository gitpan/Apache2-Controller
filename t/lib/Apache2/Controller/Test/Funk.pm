=head1 NAME

Apache2::Controller::Test::Funk

=head1 SYNOPSIS

Useful functions for use in Apache::Test tests for Apache2::Controller.

=over 4

=item diag()

Like the diag() from Test::More, except importing Test::More screws up
all the Apache::Test stuff.

=cut

package Apache2::Controller::Test::Funk;

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use base 'Exporter';

use Apache2::Controller::Version;

our @EXPORT_OK = qw(
    diag
);

sub diag {
    do { my $str = $_; $str =~ s{ ^ }{# }mxsg; print "$str\n"; } for @_;
}

1;
