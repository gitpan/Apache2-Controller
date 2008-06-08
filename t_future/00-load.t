#!perl -T

use Test::More tests => 6;

BEGIN {
	use_ok( 'Apache2::Controller' );
	use_ok( 'Apache2::Controller::Dispatch' );
	use_ok( 'Apache2::Controller::Uploads' );
	use_ok( 'Apache2::Controller::Session::Cookie' );
	use_ok( 'Apache2::Controller::Auth::OpenID' );
	use_ok( 'Apache2::Controller::X' );
}

diag( "Testing Apache2::Controller $Apache2::Controller::VERSION, Perl $], $^X" );
