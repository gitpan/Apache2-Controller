package TestApp::HashTree::Baz;
use base qw( Apache2::Controller );
sub allowed_methods {qw( noz )}

sub noz { 
}

1;
