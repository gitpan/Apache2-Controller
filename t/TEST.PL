#!perl
  
use strict;
use warnings FATAL => 'all';

use FindBin;

use blib;
use lib "$FindBin::Bin/lib";

use Apache2::Controller::Test::TestRun ();
  
Apache2::Controller::Test::TestRun->new->run(@ARGV);

