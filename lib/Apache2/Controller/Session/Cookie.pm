package Apache2::Controller::Session::Cookie;

=head1 NAME

Apache2::Controller::Session::Cookie - track a sessionid with a cookie in A2C

=head1 SYNOPSIS

See L<Apache2::Controller::Session> for detailed setup example.

 package MyApp::Session;
 use base qw( Apache2::Controller::Session::Cookie );
 sub get_options {
     # ...
 }
 1;

=head1 DESCRIPTION

This module implements C<get_session_id> and C<set_session_id>
to get and set the session id from
a cookie.  

=head1 DIRECTIVES

=over4 

=item A2CSessionCookieName

=item A2CSessionCookieExpires

See L<Apache2::Cookie> for valid fixed-duration strings.

=item A2CSessionCookiePath

Restrict the cookie path to something other than the default.

=item A2CSessionCookieSecure

Set the 'secure' flag on the cookie, which means it works only
when transmitted by HTTPS.

=back

=head1 METHODS

These methods must by implemented by any 
L<Apache2::Controller::Session> subclass.

=cut

use strict;
use warnings;
use English '-no_match_vars';

use base qw( Apache2::Controller::Session );

use Log::Log4perl qw(:easy);
use Readonly;
use YAML::Syck;

use Apache2::Controller::X;

Readonly my $DEFAULT_COOKIE_NAME => 'A2CSession';

=head2 get_session_id

 my $sid = $self->get_session_id();

Get the session id from the cookie.

Sets C<<$r->notes->{session_id}>> to be the session id string.

Sets C<<$r->pnotes->{session_cookie}>> to be the Apache2::Cookie object.

=cut

sub get_session_id {
    my ($self) = @_;

    my $cookie_name = $self->get_directive('A2CSessionCookieName') 
        || $DEFAULT_COOKIE_NAME;
    
    my $jar = $self->get_cookie_jar();

    DEBUG("looking for cookie name '$cookie_name'");
    my $cookie = $jar->cookies($cookie_name);

    DEBUG($cookie ? "found cookie!" : "did not find cookie.");

    my $sid = $cookie ? $cookie->value : undef;

    my $r = $self->{r};
    $r->notes->{session_id} = $sid || '';
    $r->pnotes->{session_cookie} = $cookie;
    
    return $sid;
}

=head2 set_session_id

 $self->set_session_id($sid);

Set the session id in the cookie.

=cut

sub set_session_id {
    my ($self, $session_id) = @_;
    DEBUG("Setting session_id '$session_id'");
    my $r = $self->{r};
    my $cookie = $r->pnotes->{session_cookie};

    my $directives = $self->get_directives();

    my %copts 
      = map {($_->[0] => $directives->{$_->[1]})}
        grep exists $directives->{$_->[1]},
        map [$_ => 'A2CSessionCookie'.ucfirst($_)],
        qw( name expires secure domain path );
    $copts{name} ||= $DEFAULT_COOKIE_NAME;

    DEBUG(sub {"Creating session cookie with opts:\n".Dump(\%copts)});
    my $name = delete $copts{name};

    if (!$cookie) {
        $cookie = Apache2::Cookie->new( $r,
            -name           => $name,
            -value          => $session_id,
        );
    }
    $cookie->$_($copts{$_}) for keys %copts;

    DEBUG("baking cookie '$cookie'");
    $cookie->bake($r);

    DEBUG("setting in notes and pnotes");
    $r->notes->{session_id} = $session_id;
    $r->pnotes->{session_cookie} = $cookie;

    DEBUG("done setting session_id");
    return;
}

=head1 SEE ALSO

L<Apache2::Controller::Session>

L<Apache2::Cookie>

=head1 AUTHOR

Mark Hedges, C<< <hedges at scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


1; # End of Apache2::Controller::Session::Cookie
