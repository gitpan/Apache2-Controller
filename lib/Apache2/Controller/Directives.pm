package Apache2::Controller::Directives;

=head1 NAME

Apache2::Controller::Directives - custom Apache2 server configuration directives

=head1 SYNOPSIS

 # apache2 config file
 PerlModule Apache2::Controller::Directives

 # for Apache2::Controller::Render::Template settings:
 A2CRenderTemplateDir /var/myapp/templates

=cut

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use Apache::Test;
use Apache::TestUtil;

use Apache2::CmdParms ();
use Apache2::Module ();
use Apache2::Directive ();

use Apache2::Controller::X;

  # {
  #  name         => 'MyParameter',
  #  func         => __PACKAGE__ . '::MyParameter',
  #  req_override => Apache2::Const::OR_ALL,
  #  args_how     => Apache2::Const::ITERATE,
  #  errmsg       => 'MyParameter Entry1 [Entry2 ... [EntryN]]',
  # },
  # {
  #  name         => 'MyOtherParameter',
  # },
  
my @directives = (
    {
        name    => 'A2CRenderTemplateDir',
      # func    => __PACKAGE__.'::A2CRenderTemplateDir',
    },
);
Apache2::Module::add(__PACKAGE__, \@directives);

=head1 DIRECTIVES

=head2 A2CRenderTemplateDir

This is the base path for templates used by 
Apache2::Controller::Render::Template.  The directive takes only
one parameter and verifies that the directory exists and is readable.
(At startup time Apache2 is root... should this verify readability by 
www user?)

=cut

sub A2CRenderTemplateDir {
    my ($self, $parms, $dir) = @_;

    Apache2::Controller::X->throw(
        "A2CRenderTemplateDir '$dir' does not exist or is not readable."
    ) unless -d $dir && -r _;

    $self->{A2CRenderTemplateDir} = $dir;
}

1;

