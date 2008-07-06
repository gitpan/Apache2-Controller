
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw( GET_BODY GET_STR );
use FindBin;

use lib "$FindBin::Bin/lib";
use Apache2::Controller::Test::Funk qw( diag );
use YAML::Syck;
use URI::Escape;

my @CHARS = ('A'..'Z', 'a'..'z', 0 .. 9);
my %TD = (
    foo     => {
        boz     => [qw( noz schnoz )]
    },
    bar     => 'biz',
    floobie => join('', map $CHARS[int(rand @CHARS)], 1 .. 50),
);
my $testdata_dump = Dump(\%TD);

plan tests => 2, need_lwp;
Apache::TestRequest::user_agent(cookie_jar => {});

use TestApp::Session::Controller;

my $url = "/session";

my $get = "$url/set?data=".uri_escape($testdata_dump);
my $response = GET_BODY $get;

diag("$get:\n".GET_STR $get);

ok t_cmp($response, "Set session data.\n", "Set data.");

$response = GET_BODY "$url/read";
diag($response);
my $session = Load($response);
my $response_testdata = $session->{testdata};

ok t_cmp(Dump($response_testdata), $testdata_dump, "Read data.");

