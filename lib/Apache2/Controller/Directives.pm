package Apache2::Controller::Directives;

=head1 NAME

Apache2::Controller::Directives - server config directives for A2C

=head1 VERSION

Version 0.101.111 - BETA TESTING (ALPHA?)

=cut

our $VERSION = version->new('0.101.111');

=head1 SYNOPSIS

 # apache2 config file
 PerlLoadModule Apache2::Controller::Directives

 # for Apache2::Controller::Render::Template settings:
 A2CRenderTemplatePath /var/myapp/templates

 # etc.

=cut

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use Carp qw( croak );
use Log::Log4perl qw(:easy);
use YAML::Syck;

use Apache2::Module ();
use Apache2::Const -compile => qw( OR_ALL TAKE1 ITERATE ITERATE2 );

my @directives = (

    # template rendering
    { 
        name            => 'A2CRenderTemplatePath',
        func            => __PACKAGE__.'::A2CRenderTemplatePath',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE,
        errmsg          => 'A2CRenderTemplatePath /primary/path [/second ... [/n]]',
    },
    {
        name            => 'A2CRenderTemplateOpts',
        func            => __PACKAGE__.'::A2CRenderTemplateOpts',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE2,
        errmsg          => q{
            # specify Template Toolkit options:
            A2CRenderTemplateOpts INTERPOLATE 1
            A2CRenderTemplateOpts PRE_PROCESS header scripts style
            A2CRenderTemplateOpts POST_CHOMP  1
        },
    },

    # session stuff
    {
        name            => 'A2CSessionClass',
        func            => __PACKAGE__.'::A2CSessionClass',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::TAKE1,
        errmsg          => 'example: A2CSessionClass Apache::Session::File'
    },
    {
        name            => 'A2CSessionOptions',
        func            => __PACKAGE__.'::A2CSessionOptions',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE2,
        errmsg          => q{
            # specify options for chosen Apache::Session subclass.
            # example:
            A2CSessionOptions   Directory       /tmp/sessions
            A2CSessionOptions   LockDirectory   /var/lock/sessions
        },
    },
    {
        name            => 'A2CSessionCookieOptions',
        func            => __PACKAGE__.'::A2CSessionCookieOptions',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE2,
        errmsg          => q{
            # specify Apache2::Cookie options for session cookie.
            # example:
            A2CSessionCookieOptions   name       myapp_sessionid
            A2CSessionCookieOptions   expires    +3M
        },
    },

    # ...SQL::Connector
    {
        name            => 'A2C_DBI_DSN',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::TAKE1,
        errmsg          => 'example: A2C_DBI_DSN DBI:mysql:database=foo',
    },
    {
        name            => 'A2C_DBI_User',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::TAKE1,
        errmsg          => 'example: A2C_DBI_User database_username',
    },
    {
        name            => 'A2C_DBI_Password',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::TAKE1,
        errmsg          => 'example: A2C_DBI_Password database_password',
    },
    {
        name            => 'A2C_DBI_Options',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE2,
        errmsg          => q{
            # specify DBI connect() options:
            A2C_DBI_Options RaiseError 1
            A2C_DBI_Options AutoCommit 0
        },
    },
);

Apache2::Module::add(__PACKAGE__, \@directives);

=head1 DIRECTIVES

=head2 A2CRenderTemplatePath

This is the base path for templates used by 
Apache2::Controller::Render::Template.  The directive takes only
one parameter and verifies that the directory exists and is readable.

(At startup time Apache2 is root... this should verify readability by 
www user?  Hrmm how is it going to figure out what user that is?
It will have to access the server config via $parms. Except that
this does not appear to work?  It returns an empty hash.)

=cut

sub A2CRenderTemplatePath {
    my ($self, $parms, @directories) = @_;

    # uhh... this doesn't work?
  # my $srv_cfg = Apache2::Module::get_config($self, $parms->server);
  # DEBUG(sub{"SERVER CONFIG:\n".Dump({
  #     map {("$_" => $srv_cfg->{$_})} keys %{$srv_cfg}
  # }) });
  # DEBUG("server is ".$parms->server);

    croak("A2CRenderTemplatePath '$_' does not exist or is not readable.") 
        for grep !( -d $_ && -r _ ), @directories;

    my $current = $self->{A2CRenderTemplatePath} || [ ];
  # DEBUG("pushing (@directories) to (@{$current})");

    push @{ $self->{A2CRenderTemplatePath} }, @directories;
}

=head2 A2CRenderTemplateOpts

 <location "/where/template/is/used">
     A2CRenderTemplateOpts INTERPOLATE 1
     A2CRenderTemplateOpts PRE_PROCESS header meta style scripts
     A2CRenderTemplateOpts POST_CHOMP  1
 </location>

Options for Template Toolkit.  See L<Template>.

You can also implement C<<get_template_opts>> in your controller subclass,
which simply returns the hash reference of template options.
See L<Apache2::Controller::Render::Template>.

Note the behavior is to merge values specified at multiple levels
into array references.  i.e. a subdirectory could specify an
additional C<<PRE_PROCESS>> template or whatever.  YMMV.
It should be this way, at any rate!

=cut

sub A2CRenderTemplateOpts {
    my ($self, $parms, $key, @vals) = @_;
    $self->_hash_assign('A2CRenderTemplateOpts', $key, @vals);
    return;
}

=head2 A2CSessionClass

 A2CSessionClass Apache::Session::File

Single argument, the class for the tied session hash.  L<Apache::Session>.

=cut

sub A2CSessionClass {
    my ($self, $parms, $class) = @_;
    $self->{A2CSessionClass} = $class;
}

=head2 A2CSessionOptions

Multiple arguments

 A2CSessionOptions   Directory       /tmp/sessions
 A2CSessionOptions   LockDirectory   /var/lock/sessions

=cut

sub A2CSessionOptions {
    my ($self, $parms, $key, @vals) = @_;
    $self->_hash_assign('A2CSessionOptions', $key, @vals);
    return;
}

=head2 A2CSessionCookieOptions

 A2CSessionCookieOptions name    myapp_sessionid
 A2CSessionCookieOptions expires +3M

Multiple arguments.  
L<Apache2::Controller::Session::Cookie>,
L<Apache2::Cookie>

=cut

sub A2CSessionCookieOptions {
    my ($self, $parms, $key, @vals) = @_;
    $self->_hash_assign('A2CSessionCookieOptions', $key, @vals);
    return;
}

=head2 A2C_DBI_DSN 

 A2C_DBI_DSN        DBI:mysql:database=foobar;host=localhost

Single argument, the DSN string.  L<DBI>

=cut

sub A2C_DBI_DSN {
    my ($self, $parms, $dsn) = @_;
    $self->{A2C_DBI_DSN} = $dsn;
}

=head2 A2C_DBI_User

 A2C_DBI_User       heebee

Single argument, the DBI username.

=cut

sub A2C_DBI_User {
    my ($self, $parms, $user) = @_;
    $self->{A2C_DBI_User} = $user;
}

=head2 A2C_DBI_Password

 A2C_DBI_Password   jeebee

Single argument, the DBI password.

=cut

sub A2C_DBI_Password {
    my ($self, $parms, $password) = @_;
    $self->{A2C_DBI_Password} = $password;
}

=head2 A2C_DBI_Options

Multiple arguments

 A2C_DBI_Options    RaiseError  1
 A2C_DBI_Options    AutoCommit  0

=cut

sub A2C_DBI_Options {
    my ($self, $parms, $key, @vals) = @_;
    $self->_hash_assign('A2C_DBI_Options', $key, @vals);
    return;
}

# _hash_assign performs iterate2 options hash assignments in a 
# consistent way (or so one might hope)

sub _hash_assign {
    my ($self, $directive, $key, @vals) = @_;
    if (exists $self->{$directive}{$key}) {
        push @{$self->{$directive}{$key}}, @vals;
    }
    elsif (@vals == 1) {
        $self->{$directive}{$key} = $vals[0];
    }
    elsif (@vals > 1) {
        $self->{$directive}{$key} = \@vals;
    }
    else {
        Apache2::Controller::X->throw("No value for $directive {$key}.");
    }
    return;
}

=head1 SEE ALSO

L<Apache2::Controller>

L<Apache2::Controller::Methods/get_directive>

L<Apache2::Controller::Session>

L<Apache2::Module>

=head1 AUTHOR

Mark Hedges, C<hedges +(a t)- scriptdolphin.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Mark Hedges.  CPAN: markle

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;

