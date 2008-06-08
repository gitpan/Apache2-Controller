#!perl
  
use strict;
use warnings FATAL => 'all';
  
use blib;
use lib qw(lib);
  
use Apache::TestRunPerl ();
  
Apache::TestRunPerl->new->run(@ARGV);
