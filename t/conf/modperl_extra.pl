
#warn `pwd`;
#warn "@INC";
BEGIN {

use strict; 
use warnings;
use English '-no_match_vars';
use YAML::Syck;

# warn "INC: (@INC)\n";

use Log::Log4perl qw(:easy);
my $loginit = q{
log4perl.rootLogger=DEBUG, Screen
log4perl.appender.Screen=Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout=PatternLayout
log4perl.appender.Screen.layout.ConversionPattern=----------------------------------%n%p %M() %L:%n%m%n
};
Log::Log4perl->init(\$loginit);

use File::Spec;
my $tmp = File::Spec->tmpdir();

my $dir = File::Spec->catfile($tmp, 'A2Ctest');

do {
  # DEBUG("Creating temp directory $_");
    mkdir || die "Cannot create $_: $OS_ERROR\n";
} for grep !-d, 
    $dir, 
    map File::Spec->catfile($dir, $_), 
    qw( lock sess );
  # zwhoop!  beedododadado!


#my $openid_cache = '/tmp/Apache2-Controller.test-cache';
#mkdir $openid_cache if !-d $openid_cache;
  # DEBUG(sub {"cookies:".Dump({ map {($_ => "$jar->{$_}")} keys %{$jar} })});
#chmod(1777, $openid_cache);
 }

1;
