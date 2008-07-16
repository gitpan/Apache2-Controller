BEGIN: {
    use strict;
    use warnings;
    use English '-no_match_vars';
    eval {
        require ModPerl::MM;
        require Apache::TestMM;
    };
    if ($EVAL_ERROR) {
        warn "# No ModPerl::MM or Apache::TestMM: $EVAL_ERROR\n";
        exit 0;
    }
    Apache::TestMM->import(qw( test clean ));
}

my @scripts = qw( t/TEST );
Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

my @requires = qw(
    Apache2::CmdParms
    Apache2::Connection
    Apache2::Const
    Apache2::Cookie
    Apache2::Directive
    Apache2::Module
    Apache2::Request
    Apache2::RequestIO
    Apache2::RequestRec
    Apache2::RequestUtil
    Apache::Session
    Apache::Session::File
    Apache::Test
    Apache::TestMM
    Apache::TestRequest
    Apache::TestRunPerl
    Apache::TestUtil
    Digest::SHA
    English
    Exception::Class
    ExtUtils::MakeMaker
    File::Spec
    FindBin
    HTML::Entities
    HTTP::Status
    List::MoreUtils
    Log::Log4perl
    Readonly
    Scalar::Util
    Template
    Test::More
    URI
    URI::Escape
    YAML::Syck
    version
);

ModPerl::MM::WriteMakefile(
    NAME            => 'Apache2::Controller',
    AUTHOR          => 'Mark Hedges <hedges@scriptdolphin.org>',
    VERSION_FROM    => 'lib/Apache2/Controller.pm',
    ABSTRACT_FROM   => 'lib/Apache2/Controller.pm',
    DISTNAME        => 'Apache2-Controller',
    PL_FILES        => { },
    dist            => {'COMPRESS' => 'gzip -9f', 'SUFFIX' => 'gz'},
    PREREQ_PM       => { map {($_ => '')} @requires },
    clean           => { FILES => clean_files() },
);

sub clean_files { join ' ', @scripts }

# end
