package TestApp::Session::Session;
use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';
use File::Spec;
use Log::Log4perl qw( :easy );

use base qw( Apache2::Controller::Session::Cookie );

sub get_options {
    my ($self) = @_;
    my $tmp = File::Spec->tmpdir();
    return {
        Directory       => File::Spec->catfile($tmp, 'A2Ctest', 'sess'),
        LockDirectory   => File::Spec->catfile($tmp, 'A2Ctest', 'lock'),
    };
}

1;

