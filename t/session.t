
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw( GET_BODY GET_STR GET_HEAD );
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

plan tests => 8, need_lwp;
Apache::TestRequest::user_agent(cookie_jar => {}, requests_redirectable => 0);

use TestApp::Session::Controller;

my $url = "/session";

my $get = "$url/set?data=".uri_escape($testdata_dump);
my $response = GET_BODY $get;

ok t_cmp($response, "Set session data.\n", "Set data.");

$response = GET_BODY "$url/read";
my $session = Load($response);
my $response_testdata = $session->{testdata};

ok t_cmp(Dump($response_testdata), $testdata_dump, "Read data.");

# what about a redirect?  if i save something in a controller
# that returns redirect, does it actually get saved?
my $redirect = GET_HEAD "$url/redirect";
ok t_cmp($redirect, qr{ ^ \# Location: \s+ \Q$url\E/read }mxs, 'Redirect ok');

my $redirect_set_data = GET_BODY "$url/read";
$session = Load($redirect_set_data);
$response_testdata = Dump($session->{testdata});

ok t_cmp($response_testdata, $testdata_dump, 
    "Read data after redirect - did not save.");

my $error = GET_HEAD "$url/server_error";
ok t_cmp($error, qr{ ^ \# Title: \s+ 500 \s+ Internal \s+ Server \s+ Error }mxs,
    'error page ok' );

# check to make sure the forced-save flag works
my $redirect_force_save = GET_HEAD "$url/redirect_force_save";
ok t_cmp($redirect, qr{ ^ \# Location: \s+ \Q$url\E/read }mxs, 
    'Redirect (force save) ok');

$TD{redirect_data} = 'redirect data test';
$testdata_dump = Dump(\%TD);

my $redirect_forced_data = GET_BODY "$url/read";
$session = Load($redirect_forced_data);
$response_testdata = Dump($session->{testdata});

ok t_cmp($response_testdata, $testdata_dump, 
    "Read data after redirect with forced save - saved data.");

my $error_data_set = GET_BODY "$url/read";
$session = Load($error_data_set);
$response_testdata = Dump($session->{testdata});
diag($response_testdata);


ok t_cmp($response_testdata, $testdata_dump, "Read data after error unchanged.");

