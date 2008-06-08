
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY';
use FindBin;

use lib "$FindBin::Bin/lib";
use Apache2::Controller::Test::Funk qw( diag );
use YAML::Syck;

plan tests => 3;

my $url = "/render";

my $data = GET_BODY $url;

ok t_cmp("Top level handler.\n", $data, "render test: top level handler");

$data = GET_BODY "$url/foo/bar/biz/baz";
my $dumpstring = "bar:\n".Dump([qw( biz baz )])."\n";
ok t_cmp($dumpstring, $data, "foobar test 2");

#diag("DATA:\n".join(", ", map ord, split '', $data));
#diag("DUMPSTRING:\n".join(", ", map ord, split '', $dumpstring));

$dumpstring = "default:\n".Dump([qw( bismuth cobalt cadmium )])."\n";
$data = GET_BODY "$url/foo/bismuth/cobalt/cadmium";
ok t_cmp($dumpstring, $data, "foobar test 3");

__END__

for my $flavor (qw( apple berry peach )) {
    my $url = "/test/a2c/render/pie/$flavor";
    my $data = GET_BODY $url;
    
    diag("flavor: $flavor, data:\n$data---\n");
    ok t_cmp("Simple as $flavor pie.\n", $data, "render test: $flavor");
}

