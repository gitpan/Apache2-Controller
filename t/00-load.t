#!/usr/bin/perl

use Test::More;
use blib;

# Can't load Apache2::Controller::Directives outside of modperl environment

BEGIN {
    my @libs = qw(
        Apache2::Controller::Auth::OpenID
        Apache2::Controller::Const
        Apache2::Controller::Dispatch::Simple
        Apache2::Controller::Dispatch
        Apache2::Controller::Funk
        Apache2::Controller::Render::Template
        Apache2::Controller::Session::Cookie
        Apache2::Controller::Session
        Apache2::Controller::Uploads
        Apache2::Controller::X
        Apache2::Controller
    );

    plan tests => scalar @libs;
    use_ok($_) for @libs;
}

diag( "Testing Apache2::Controller $Apache2::Controller::VERSION, Perl $], $^X" );
