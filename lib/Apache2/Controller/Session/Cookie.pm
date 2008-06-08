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

This module implements get_session_id to get the session id from
a cookie.  The cookie's path is the <Location> in which you said
to use your Apache2::Controller::Session subclass as a handler.

=head1 SEE ALSO

L<Apache2::Controller::Session>

=head1 AUTHOR

Mark Hedges, C<< <hedges at scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

use strict;
use warnings;
use English '-no_match_vars';

use Log::Log4perl qw(:easy);
use Readonly;

Readonly my $DEFAULT_COOKIE_NAME => 'A2CSession';

sub get_session_id {
    my ($self) = @_;

    my $cookie_name = $self->get_directive('A2CSessionCookieName') 
        || $DEFAULT_COOKIE_NAME;
    
    my $cookies = $self->get_cookies();

    my $session_cookie = $cookies->{$cookie_name};
    my $sid = $session_cookie ? $session_cookie->value : undef;

    $self->notes->{session_id} = $sid || '';
    $self->pnotes->{session_cookie} = $session_cookie;
    
    return $sid;
}

sub set_session_id {
    my ($self) = @_;
    my $session_cookie = $self->pnotes->{session_cookie};

    # set the cookie contents....
}


1; # End of Apache2::Controller::Session::Cookie
