package TestApp::Simple::Dispatch;

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use base qw( 
    Apache2::Controller::Dispatch 
    Apache2::Controller::Dispatch::Simple
);

use Log::Log4perl qw(:easy);

our %dispatch_map = (
    default     => 'TestApp::Simple::C::Top',
);

our @limit_http_methods = qw( GET POST );

1;
