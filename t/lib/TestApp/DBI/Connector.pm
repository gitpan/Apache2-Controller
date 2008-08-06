package TestApp::DBI::Connector;

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use File::Spec;
use DBI;

use base qw( Apache2::Controller::DBI::Connector );

my $tmp  = File::Spec->tmpdir();
my $sqlfile = File::Spec->catfile( $tmp, "A2C_Test_DBI_Connector.$$.sqlite" );

my @dbi_args = ( "dbi:SQLite:dbname=$sqlfile", '', '', {
    RaiseError => 1,
    PrintError => 0,
    PrintWarn  => 0,
  # AutoCommit => 0,
});

sub dbi_connect_args {
    my ($self) = @_;
    return @dbi_args;
}

sub dbi_cleanup { 1 }

1;
