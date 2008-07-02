
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw( GET_BODY GET_STR );
use FindBin;

use lib "$FindBin::Bin/lib";
use Apache2::Controller::Test::Funk qw( diag );
use YAML::Syck;

plan tests => 2, need_lwp;
Apache::TestRequest::user_agent(cookie_jar => {});

use TestApp::Session::Controller;
my %testdata = %TestApp::Session::Controller::testdata;

my $url = "/session";

my $response = GET_BODY "$url/set";

diag($response);

ok t_cmp("Set session data.\n", $response, "Set data.");

$response = GET_BODY "$url/read";
diag($response);
my $session = Load($response);
my $response_testdata = $session->{testdata};

ok t_cmp(Dump($response_testdata), Dump(\%testdata), "Read data.");

