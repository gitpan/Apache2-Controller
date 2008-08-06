package Apache2::Controller::Directives;

=head1 NAME

Apache2::Controller::Directives - server config directives for A2C

=head1 VERSION

Version 0.110.000 - BETA TESTING (ALPHA?)

=cut

our $VERSION = version->new('0.110.000');

=head1 SYNOPSIS

 # apache2 config file
 PerlLoadModule Apache2::Controller::Directives

 # for Apache2::Controller::Render::Template settings:
 A2C_Render_Template_Path /var/myapp/templates

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

    # dispatch
    {
        name            => 'A2C_Dispatch_Map',
        func            => __PACKAGE__.'::A2C_Dispatch_Map',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE,
        errmsg          => 'A2C_Dispatch_Map /path/to/yaml/syck/dispatch/map/file',
    },

    # template rendering
    { 
        name            => 'A2C_Render_Template_Path',
        func            => __PACKAGE__.'::A2C_Render_Template_Path',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE,
        errmsg          => 'A2C_Render_Template_Path /primary/path [/second ... [/n]]',
    },
    {
        name            => 'A2C_Render_Template_Opts',
        func            => __PACKAGE__.'::A2C_Render_Template_Opts',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE2,
        errmsg          => q{
            # specify Template Toolkit options:
            A2C_Render_Template_Opts INTERPOLATE 1
            A2C_Render_Template_Opts PRE_PROCESS header scripts style
            A2C_Render_Template_Opts POST_CHOMP  1
        },
    },

    # session stuff
    {
        name            => 'A2C_Session_Class',
        func            => __PACKAGE__.'::A2C_Session_Class',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::TAKE1,
        errmsg          => 'example: A2C_Session_Class Apache::Session::File'
    },
    {
        name            => 'A2C_Session_Opts',
        func            => __PACKAGE__.'::A2C_Session_Opts',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE2,
        errmsg          => q{
            # specify options for chosen Apache::Session subclass.
            # example:
            A2C_Session_Opts   Directory       /tmp/sessions
            A2C_Session_Opts   LockDirectory   /var/lock/sessions
        },
    },
    {
        name            => 'A2C_Session_Cookie_Opts',
        func            => __PACKAGE__.'::A2C_Session_Cookie_Opts',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::ITERATE2,
        errmsg          => q{
            # specify Apache2::Cookie options for session cookie.
            # example:
            A2C_Session_Cookie_Opts   name       myapp_sessionid
            A2C_Session_Cookie_Opts   expires    +3M
        },
    },

    # A2C:DBI::Connector
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
    {
        name            => 'A2C_DBI_Cleanup',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::TAKE1,
        errmsg          => 'example: A2C_DBI_Cleanup 1',
    },
    {
        name            => 'A2C_DBI_Class',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::TAKE1,
        errmsg          => 'example: A2C_DBI_Class MyApp::DBI',
    },
    {
        name            => 'A2C_DBI_Pnotes_Name',
        req_override    => Apache2::Const::OR_ALL,
        args_how        => Apache2::Const::TAKE1,
        errmsg          => 'example: A2C_DBI_Pnotes_Name reader',
    },
);

Apache2::Module::add(__PACKAGE__, \@directives);

=head1 Apache2::Controller::Dispatch

See L<Apache2::Controller::Dispatch>

=head2 A2C_Dispatch_Map

This is the path to a file compatible with L<YAML::Syck>.
If you do not provide a C<< dispatch_map() >> subroutine,
the hash will be loaded with this file.

Different subclasses of L<Apache2::Controller::Dispatch>
have different data structures.  YMMV.

Or, if you just specify a package name, it will generate
a dispatch map with one 'default' entry with that package.

=cut

sub A2C_Dispatch_Map {
    my ($self, $parms, $value) = @_;

    if ($value =~ m{ :: }mxs) {
        $self->{A2C_Dispatch_Map} = { default => $value };
        return;
    }

    my $file = $value;
  # DEBUG("using file '$file' as A2C_Dispatch_Map");
    croak "A2C_Dispatch_Map $file does not exist or is not readable."
        if !(-e $file && -f _ && -r _);
    
    # why not go ahead and load the file!
    $self->{A2C_Dispatch_Map} = LoadFile($file)
        || croak "Could not load A2C_Dispatch_Map $file: $OS_ERROR";

  # DEBUG("success!");
    return;
}

=head1 Apache2::Controller::Render::Template

See L<Apache2::Controller::Render::Template>.

=head2 A2C_Render_Template_Path

This is the base path for templates used by 
Apache2::Controller::Render::Template.  The directive takes only
one parameter and verifies that the directory exists and is readable.

(At startup time Apache2 is root... this should verify readability by 
www user?  Hrmm how is it going to figure out what user that is?
It will have to access the server config via $parms. Except that
this does not appear to work?  It returns an empty hash.)

=cut

sub A2C_Render_Template_Path {
    my ($self, $parms, @directories) = @_;

    # uhh... this doesn't work?
  # my $srv_cfg = Apache2::Module::get_config($self, $parms->server);
  # DEBUG(sub{"SERVER CONFIG:\n".Dump({
  #     map {("$_" => $srv_cfg->{$_})} keys %{$srv_cfg}
  # }) });
  # DEBUG("server is ".$parms->server);

    croak("A2C_Render_Template_Path '$_' does not exist or is not readable.") 
        for grep !( -d $_ && -r _ ), @directories;

    my $current = $self->{A2C_Render_Template_Path} || [ ];
  # DEBUG("pushing (@directories) to (@{$current})");

    push @{ $self->{A2C_Render_Template_Path} }, @directories;
}

=head2 A2C_Render_Template_Opts

 <location "/where/template/is/used">
     A2C_Render_Template_Opts INTERPOLATE 1
     A2C_Render_Template_Opts PRE_PROCESS header meta style scripts
     A2C_Render_Template_Opts POST_CHOMP  1
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

sub A2C_Render_Template_Opts {
    my ($self, $parms, $key, @vals) = @_;
    $self->_hash_assign('A2C_Render_Template_Opts', $key, @vals);
    return;
}

=head1 Apache2::Controller::Session

See L<Apache2::Controller::Session>.

=head2 A2C_Session_Class

 A2C_Session_Class Apache::Session::File

Single argument, the class for the tied session hash.  L<Apache::Session>.

=cut

sub A2C_Session_Class {
    my ($self, $parms, $class) = @_;
    $self->{A2C_Session_Class} = $class;
}

=head2 A2C_Session_Opts

Multiple arguments

 A2C_Session_Opts   Directory       /tmp/sessions
 A2C_Session_Opts   LockDirectory   /var/lock/sessions

=cut

sub A2C_Session_Opts {
    my ($self, $parms, $key, @vals) = @_;
    $self->_hash_assign('A2C_Session_Opts', $key, @vals);
    return;
}

=head2 A2C_Session_Cookie_Opts

 A2C_Session_Cookie_Opts name    myapp_sessionid
 A2C_Session_Cookie_Opts expires +3M

Multiple arguments.  
L<Apache2::Controller::Session::Cookie>,
L<Apache2::Cookie>

=cut

sub A2C_Session_Cookie_Opts {
    my ($self, $parms, $key, @vals) = @_;
    $self->_hash_assign('A2C_Session_Cookie_Opts', $key, @vals);
    return;
}

=head1 Apache2::Controller::DBI::Connector

See L<Apache2::Controller::DBI::Connector>.

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

Multiple arguments.

 A2C_DBI_Options    RaiseError  1
 A2C_DBI_Options    AutoCommit  0

=cut

sub A2C_DBI_Options {
    my ($self, $parms, $key, @vals) = @_;
    $self->_hash_assign('A2C_DBI_Options', $key, @vals);
    return;
}

=head2 A2C_DBI_Cleanup

Boolean.  

 A2C_DBI_Cleanup        1

=cut

sub A2C_DBI_Cleanup {
    my ($self, $parms, $val) = @_;
    $self->{A2C_DBI_Cleanup} = $val;
    return;
}

=head2 A2C_DBI_Pnotes_Name

String value.

 A2C_DBI_Pnotes_Name    reader

=cut

sub A2C_DBI_Pnotes_Name {
    my ($self, $parms, $val) = @_;
    $self->{A2C_DBI_Pnotes_Name} = $val;
    return;
}

=head2 A2C_DBI_Class

If you subclass DBI, specify the name of your DBI subclass here.

 A2C_DBI_Class      MyApp::DBI

Note that this is connected with a string eval which is slow.
If you don't use it, it uses a block eval to connect DBI.

=cut

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

