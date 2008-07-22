package Apache2::Controller::Auth::OpenID;

=head1 NAME

Apache2::Controller::Auth::OpenID - OpenID base for Apache2::Controller::Dispatch

=head1 SYNOPSIS

 # vhost.conf
 <Perl>
    my $openid_cache = '/dev/shm/myapp_openid_cache';
    mkdir $openid_cache if !-d $openid_cache;
    chown $EUID, $EGID, $open_id_cache
        || die "failed to `chown $EUID $EGID $openid_cache`";
 </Perl>
 
 <Location /myapp>
     SetHandler modperl
     PerlOptions +SetupEnv
     PerlInitHandler MyApp::Dispatch
 </Location>

 # lib/MyApp/Dispatch:
 package MyApp::Dispatch;

 use base qw(
     Apache2::Controller::Dispatch
     Apache2::Controller::Session::Cookie
     Apache2::Controller::Auth::OpenID
 );

 our %dispatch_map = (
     foo        => 'MyApp::C::Foo',
     login      => 'MyApp::C::Login',  # 'login' url required
 );

 # implement the following methods in your dispatch class.

 # get_openid_url(): get the openid_url of user.
 # this example gets it out of a cookie, but you may have another
 # mechanism, for instance, maybe you have it stashed in the
 # session database store

 sub get_openid_url {
     my ($self) = @_;
     my $cookies = $self->get_cookies();
     my $cookie_openid_url = $cookies->{'openid_url'};
     my $openid_url = $cookie_openid_url ? $cookie_openid_url->value : undef;
     return $openid_url;
 }

 # is_logged_in(): is the user logged in?
 
 sub is_logged_in

 1;

=head1 DESCRIPTION

Implements a verify_auth() method for L<Apache2::Controller::Dispatch>
that uses OpenID.  

=cut

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

=head1 METHODS

=head2 verfiy_auth

verify_auth() implements the auth check for a module
based on Apache2::Controller::Dispatch.

=cut

sub verify_auth {
    my ($self) = @_;
    my $r = $self->{r};

    my $openid_url = $self->get_openid_url();
    $r->notes->{openid_url} = $openid_url || '';

    return 1;  # UNIMPLEMENTED
}

=head1 AUTHOR

Mark Hedges, C<< <hedges at scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Apache2::Controller::Auth::OpenID
