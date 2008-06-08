package Apache2::Controller::Methods;

=head1 NAME

Apache2::Controller::Methods - methods shared by Apache2::Controller modules

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

=head2 get_directives( )

 my $directives_hashref = $self->get_directives();

Returns the Apache2::Controller::Directives config hash for this request,
with per-directory settings.

NOTE: directives don't work because of problems with Apache::Test.
For now it returns \%ENV instead.

=cut

sub get_directives {
    my ($self) = @_;

    my $r = $self->{r};

    $r->pnotes->{directives} ||= Apache2::Module::get_config(
        'Apache2::Controller::Directives',
        $r->server(),
        $r->per_dir_config(),
    );

    # since my directives don't work under Apache::Test I look for
    # the names of the same vars in %ENV until they do.  blah.
    $r->pnotes->{directives} ||= \%ENV;
    return $r->pnotes->{directives};
}

=head2 get_directive( )

 my $value = $self->get_directive( $A2CDirectiveNameString )

Returns the value of the given directive name.  Does not die if
get_directives() returns an empty hash.

NOTE: directives don't work because of problems with Apache::Test.
For now it returns values from %ENV instead.

=cut

sub get_directive {
    my ($self, $directive) = @_;

    # temporarily i'm getting variables from ENV until I work out
    # why directives don't work right with Apache2::Test.

    Apache2::Controller::X->throw('usage: $self->get_directive($directive)') 
        if !$directive;
    my $directives = $self->get_directives();
    DEBUG(sub {"directives:\n".Dump($directives)});
    return $directives->{$directive};
}

=head2 get_apache2_request_opts( )

 my %opts = $self->get_apache2_request_opts( $controller_class_name );

Returns the Apache2::Request options hash (i.e. POST_MAX and TEMP_DIR, etc.) 
for a given
Apache2::Controller controller module class name.  Caches this information
for speedup.

=cut

my %apache2_request_opts = ( );

sub get_apache2_request_opts {
    my ($self, $controller) = @_;
    Apache2::Controller::X->throw(
        'usage: $self->get_apache2_request_opts($controller_class)'
    ) if !$controller || ref $controller;

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

=head2 get_cookies( )

 my $cookies = $self->get_cookies();

Fetches cookies with Apache2::Cookie->fetch.  Caches them in 
$self->pnotes->{cookies} for the duration of the request.

=cut

sub get_cookies {
    my ($self) = @_;
    my $r = $self->{r};
    my $cookies = $r->pnotes->{cookies};
    return $cookies if defined $cookies;
    $cookies = Apache2::Cookie->fetch($r);
    DEBUG(sub {"cookies:".Dump({ map {($_ => $cookies->{$_})} keys %{$cookies} })});
    $r->pnotes->{cookies} = $cookies;
    return $cookies;
}

=head1 SEE ALSO

L<Apache2::Controller>

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

