package Apache2::Controller::Methods;

=head1 NAME

Apache2::Controller::Methods - methods shared by Apache2::Controller modules

=head1 VERSION

Version 1.000.011

=cut

use version;
our $VERSION = version->new('1.000.011');

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

use Apache2::Module ();
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

    my $directives = $r->pnotes->{a2c}{directives};
    return $directives if $directives;

    $directives = Apache2::Module::get_config(
        'Apache2::Controller::Directives',
        $r->server(),
        $r->per_dir_config(),
    );

    DEBUG sub{"directives found:\n".Dump($directives)};

    $r->pnotes->{a2c}{directives} = $directives;
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

=head2 get_cookie_jar

 my $jar = $self->get_cookie_jar();

Gets the Apache2::Cookie::Jar object.

Does NOT cache the jar in any way, as this is the business 
of C<Apache2::Cookie>, and input headers could possibly change
via filters, and it would create a circular reference to C<< $r >>
if you stuck it in pnotes.

See L<Apache2::Cookie>.

=cut

sub get_cookie_jar {
    my ($self) = @_;
    my $r = $self->{r};
    my $jar = Apache2::Cookie::Jar->new($r);
    DEBUG sub {
        my @cookie_names = $jar->cookies;
        return
            "raw cookie header: "
            .($r->headers_in->{Cookie} || '[no cookies]')
            ."\n"
            ."cookie names in jar:\n"
            .Dump(\@cookie_names)
    };
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

This software is provided as-is, with no warranty 
and no guarantee of fitness
for any particular purpose.

=cut

1;

