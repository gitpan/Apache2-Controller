#!perl 

use Test::More tests => 17;
use blib;

BEGIN {
    use_ok("Apache2::Controller");
    use_ok("Apache2::Controller::Const");
#   use_ok("Apache2::Controller::Directives");
    use_ok("Apache2::Controller::Dispatch");
    use_ok("Apache2::Controller::Dispatch::Simple");
    use_ok("Apache2::Controller::Dispatch::HashTree");
    use_ok("Apache2::Controller::Dispatch::RenderTemplate");
    use_ok("Apache2::Controller::Funk");
    use_ok("Apache2::Controller::Log::DetectAbortedConnection");
    use_ok("Apache2::Controller::Methods");
    use_ok("Apache2::Controller::NonResponseBase");
    use_ok("Apache2::Controller::Render::Template");
    use_ok("Apache2::Controller::Session");
    use_ok("Apache2::Controller::Session::Cookie");
    use_ok("Apache2::Controller::SQL::Connector");
    use_ok("Apache2::Controller::SQL::MySQL");
    use_ok("Apache2::Controller::Uploads");
    use_ok("Apache2::Controller::X");
}

diag('');
diag('Testing Apache2::Controller '.$Apache2::Controller::VERSION);
diag('Numeric version is '.$Apache2::Controller::VERSION->numify);
diag("Perl $], $^X");
