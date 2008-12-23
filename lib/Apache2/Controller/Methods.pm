package Apache2::Controller::Methods;

=head1 NAME

Apache2::Controller::Methods - methods shared by Apache2::Controller modules

=head1 VERSION

Version 1.000.001 - FIRST RELEASE

=cut

use version;
our $VERSION = version->new('1.000.001');

=head1 SYNOPSIS

 package Apache2::Controller::SomeNewBrilliantPlugin;

 use base qw( Apache2::Controller::Methods );

 # ...
 my $directives = $self->get_directives();
 my $directive  = $self->get_directive('A2CSomethingSomething');

=head1 DESCRIPTION

Methods shared in common by various Apache2::Controller modules, 
like L<Apache2::Controller>, L<Apache2::Controller::Dispatch>, etc.

Note: In this module we always dereference C<$self->{r}>,
because we don't know if $self is blessed as an Apache2::Request
yet or not.  (This package is used as a base by multiple handler stages.)

=head1 METHODS

=cut

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use Apache2::Controller::X;
use Apache2::Cookie;
use YAML::Syck;
use Log::Log4perl qw( :easy );

=head2 get_directives

 my $directives_hashref = $self->get_directives();

Returns the L<Apache2::Controller::Directives> config hash for this request,
with per-directory settings.

NOTE: real directives don't work because of problems with Apache::Test.
For now use C<PerlSetVar>.

When directives work, if you mix A2C Directives with PerlSetVar
statements in Apache config, the directives take precedence
and the PerlSetVar values are not merged.  Hrmm.  
Well, I think there's a method, but I've got better
things to work on right now.

=cut

sub get_directives {
    my ($self) = @_;

    my $r = $self->{r};

    my $directives = $r->pnotes->{directives};
    return $directives if $directives;

    $directives = Apache2::Module::get_config(
        'Apache2::Controller::Directives',
        $r->server(),
        $r->per_dir_config(),
    );

    DEBUG sub{"directives found:\n".Dump($directives)};

    $r->pnotes->{directives} = $directives;
    return $directives;
}

=head2 get_directive

 my $value = $self->get_directive( $A2CDirectiveNameString )

Returns the value of the given directive name.  Does not die if
get_directives() returns an empty hash.

NOTE: directives don't work because of problems with Apache::Test.
For now use C<PerlSetVar>.

=cut

sub get_directive {
    my ($self, $directive) = @_;

    a2cx 'usage: $self->get_directive($directive)' if !$directive;
    my $directives = $self->get_directives();
    my $directive_value = $directives->{$directive};
    DEBUG sub { 
        "directive $directive = "
        .(defined $directive_value ? "'$directive_value'" : '[undef]')
    };
    return $directive_value;
}

=head2 get_apache2_request_opts

 my %opts = $self->get_apache2_request_opts( $controller_class_name );

Returns the Apache2::Request options hash (i.e. POST_MAX and TEMP_DIR, etc.) 
for a given
Apache2::Controller controller module class name.  Caches this information
for speedup.

=cut

my %apache2_request_opts = ( );

sub get_apache2_request_opts {
    my ($self, $controller) = @_;
    a2cx 'usage: $self->get_apache2_request_opts($controller_class)'
        if !$controller || ref $controller;

    if (!exists $apache2_request_opts{$controller}) {
        my $directives = $self->get_directives();
        my %opts;
        eval '$opts{TEMP_DIR} = $'.$controller.'::TEMP_DIR;';
        eval '$opts{POST_MAX} = $'.$controller.'::POST_MAX;';

        do { $opts{$_} ||= $directives->{"A2C_$_"} if $directives->{"A2C_$_"} }
            for qw( TEMP_DIR POST_MAX );
        delete $opts{$_} for grep !defined $opts{$_}, keys %opts;
        $apache2_request_opts{$controller} = \%opts;
    }

    return %{ $apache2_request_opts{$controller} };
}

=head2 get_cookie_jar

 my $jar = $self->get_cookie_jar();

Fetches cookies with Apache2::Cookie::Jar.  Caches them in 
C<<$self->pnotes->{cookie_jar}>> for the duration of the request.
Further calls to get_cookie_jar() from any handler will return the
same jar without re-parsing them.

=cut

sub get_cookie_jar {
    my ($self) = @_;
    my $r = $self->{r};
    DEBUG(sub {"raw cookie headers: ".($r->headers_in->{Cookie} || '[no cookies]') });
    DEBUG('searching for cookie_jar in r->pnotes->{cookie_jar}');
    my $jar = $r->pnotes->{cookie_jar};
    return $jar if defined $jar;
    DEBUG('did not find cookie_jar in pnotes');
    $jar = Apache2::Cookie::Jar->new($r);
    my @cookie_names = $jar->cookies;
    DEBUG(sub {"cookie names in jar:\n".Dump(\@cookie_names)});
    $r->pnotes->{cookie_jar} = $jar;
    return $jar;
}

=head1 SEE ALSO

L<Apache2::Controller>

L<Apache2::Controller::Session>

L<Apache2::Request>

L<Apache2::Module>

L<Apache2::Directives>

L<Apache2::Cookie>

=head1 AUTHOR

Mark Hedges, C<hedges +(a t)- scriptdolphin.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Mark Hedges.  CPAN: markle

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;

