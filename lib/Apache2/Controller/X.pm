package Apache2::Controller::X;

=head1 NAME

Apache2::Controller::X - Exception::Class hierarchy for Apache2::Controller

=head1 SYNOPSIS

 package MyApp::C::Foo;
 use base qw( Apache2::Controller ); 
 use Apache2::Controller::X;
 # ...
 sub page_controller_method {
    Apache2::Controller::X::Redirect->throw('http://foo.bar');
 }

 # or subclass and extend the errors...
 
 package MyApp::X;
 use base qw( Apache2::Controller::X );
 use Exception::Class (
     'MyApp::X' => { 
         isa => 'Apache2::Controller::X',
     },
     'MyApp::X::Redirect' => { 
         isa => 'Apache2::Controller::X::Redirect',
     },
 );

 package MyApp::C::Bar;
 use base qw( Apache2::Controller );
 use Apache2::Const -compile => qw( :http );
 use MyApp::X;
 # ...
 sub page_controller_method {
     MyApp::X->throw(
          message => q{ You're not supposed to be here. },
          status => Apache2::Const::FORBIDDEN,
          dump => {
            this    => q{structure will get YAML::Syck::Dump'd},
            that    => [qw( to the error log )],
          },
     );
 }

=head1 DESCRIPTION

Hierarchy of L<Exception::Class> objects for L<Apache2::Controller>.
All are subclasses of Apache2::Controller::X.

=head1 FIELDS

All Apache2::Controller::X exceptions implement three fields:

=head2 message

Required.
The standard L<Exception::Class> message field.  If you call C<throw()>
with only one argument, a string, then this gets set as the message
field, which is displayed when the object is referred to in string context.

 eval { Apache2::Controller::X->throw("booyeah") };
 if (my $X = Exception::Class->caught('Apache2::Controller::X')) {
     warn "my exception 'message' was '$X'\n";
     warn $X->trace;
 }

=head2 status

This can be set to an L<Apache2::Const/:http> constant, which
will then be set as the status for the request.

 Apache2::Controller::X->throw(
     message => "oh no!",
     status => Apache2::Const::HTTP_INTERNAL_SERVER_ERROR,
 );

=head2 status_line

Combined with status, when intercepted by L<Apache2::Controller/handler>
this sets a custom message with L<Apache2::RequestRec/status_line>.

 Apache2::Controller::X->throw(
     message => "Warp injection coil failure in unit 3-A-73",
     status => Apache2::Const::HTTP_INTERNAL_SERVER_ERROR,
     status_line => "Turbulence ahead. Please buckle your safety belts.",
 );

This differentiation can be used to display technical information
in the log while giving a nice message to the user.

If L<Apache2::Controller::Render::Template/error> is used,
status_line is preferentially used to translate the error code,
otherwise it uses L<HTTP::Status/status_message>.

=head2 dump

An arbitrary data structure which Apache2::Controller will send
through L<YAML::Syck> Dump() when printing to the error log.

=head1 SUBCLASSES

=head2 Apache2::Controller::X

The basic exception object that implements the three basic fields.

=head2 Apache2::Controller::X::Redirect

If thrown back to the handler, the message will be used as
a url to redirect the browser.

 Apache2::Controller::X::Redirect->throw('http://foo.bar');

This works by setting $r->location(), not through an internal redirect.
If you want to do an internal redirect, just do it with 
$self->internal_redirect() inherited from Apache2::SubRequest.

=cut

use warnings FATAL => 'all';
use strict;

use Exception::Class (
    'Apache2::Controller::X'           => { 
        fields  => [qw( message dump status status_line )],
    },
    'Apache2::Controller::X::Redirect' => { 
        isa => 'Apache2::Controller::X',
    },
);

=head1 METHODS

=head2 Fields

This is the Fields() method provided by L<Exception::Class>.

=head1 SEE ALSO

L<Exception::Class>

L<Apache2::Controller>

=head1 AUTHOR

Mark Hedges, C<< <hedges ||at scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


1;
