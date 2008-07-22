#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use blib;

package TestApp::HashTree::Dispatch;

use base qw( Apache2::Controller::Dispatch::HashTree );

our %dispatch_map = (
    foo => {
        default     => 'TestApp::HashTree::Foo',
        bar => {
            biz         => 'TestApp::HashTree::Biz',
            baz         => 'TestApp::HashTree::Baz',
        },
    },
);

1;

=for comment

 /subdir/foo                    TestApp::HashTree::Foo->default()
 /subdir/foo/bar                TestApp::HashTree::Foo->bar()
 /subdir/foo/bar/zerm           TestApp::HashTree::Foo->bar(), path_args == ['zerm']
 /subdir/foo/bar/biz            TestApp::HashTree::Biz->default()
 /subdir/foo/biz/baz/noz/wiz    TestApp::HashTree::Baz->noz(), path_args == ['wiz']

=cut

package main;

use strict;
use warnings;
use English '-no_match_vars';

use Log::Log4perl qw(:easy);
use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More qw( no_plan );
use YAML::Syck;

use Apache2::Controller::Test::Mockr;
use Apache2::Controller::X;


my $tests = Load(q{
    foo:
        controller:         TestApp::HashTree::Foo
        method:             default

    'foo/bar':
        controller:         TestApp::HashTree::Foo
        method:             bar

    'foo/bar/zerm':
        controller:         TestApp::HashTree::Foo
        method:             bar
        path_args:
            - zerm

    'foo/bar/biz':
        controller:         TestApp::HashTree::Biz
        method:             default

    'foo/bar/baz/noz/wiz':
        controller:         TestApp::HashTree::Baz
        method:             noz
        path_args:
            - wiz
});

for my $uri (sort keys %{$tests}) {
    my $mock = Apache2::Controller::Test::Mockr->new(
        location            => '/subdir',
        uri                 => "/$uri",
    );
    my $dispatcher = TestApp::HashTree::Dispatch->new($mock);
    my $controller;
    eval { $controller = $dispatcher->find_controller() };
    if (my $X = Exception::Class->caught('Apache2::Controller::X')) {
        DEBUG("$X: \n".$X->trace());
        die "caught X (check logs): $X\n";
    }
    elsif ($EVAL_ERROR) {
        die "unknown error: $EVAL_ERROR\n";
    }

    my $notes = $mock->notes;

    is($notes->{$_} => $tests->{$uri}{$_}, "$uri $_") for qw( controller method );

}


1;
