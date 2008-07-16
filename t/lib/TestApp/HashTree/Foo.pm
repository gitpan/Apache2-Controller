package TestApp::HashTree::Foo;
use base qw( Apache2::Controller );
our @ALLOWED_METHODS = qw( default bar );
sub default {
}
sub bar {
}
1;
