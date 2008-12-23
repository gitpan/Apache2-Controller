=head1 NAME

Apache2::Controller::Test::Funk

=head1 SYNOPSIS

Useful functions for use in Apache::Test tests for Apache2::Controller.

=cut

package Apache2::Controller::Test::Funk;

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';
use IPC::Open3;

use base 'Exporter';

our @EXPORT = qw(
    diag
    od
);

=head2 diag

Like the diag() from Test::More, except importing Test::More screws up
all the Apache::Test stuff.

=cut

sub diag {
    my @args = @_;
    defined && do { s{^}{# }mxsg; print "$_\n" } for @args;
}

=head2 od

diag the argument string through `od -a` using L<IPC::Open3>.

=cut

sub od {
    my ($string) = @_;
    my ($wtr, $rdr, $err, $od_out);
    my $pid = open3($wtr, $rdr, $err, 'od -a');
    print $wtr $string;
    close $wtr;
    {
        local $/ = 1;
        $od_out = <$rdr> || <$err>;
    }
    close $rdr;
    close $err if $err;
    diag($od_out);
}

1;
