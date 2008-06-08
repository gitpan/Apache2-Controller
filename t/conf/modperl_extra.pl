
warn `pwd`;
warn "@INC";

use Log::Log4perl;
my $logconf = q{
log4perl.rootLogger=DEBUG, Screen
log4perl.appender.Screen=Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout=PatternLayout
log4perl.appender.Screen.layout.ConversionPattern=%d %p %M() (%L):%n    %m%n
};
Log::Log4perl->init(\$logconf);

my $openid_cache = '/tmp/Apache2-Controller.test-cache';
mkdir $openid_cache if !-d $openid_cache;
chmod(1777, $openid_cache);

