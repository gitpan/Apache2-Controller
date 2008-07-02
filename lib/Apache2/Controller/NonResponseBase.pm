package Apache2::Controller::NonResponseBase;

=head1 NAME

Apache2::Controller::NonResponseBase - internal base class for 
non-response handlers in Apache2::Controller framework

=head1 SYNOPSIS

This is an INTERNAL base class and you don't need to use it.

 package Apache2::Controller;
 use base Apache2::Controller::NonResponseBase;

 # no need to define handler() or new()
 
 1;

=head1 DESCRIPTION

This factors out the common parts of handlers in the C<Apache2::Controller>
framework other than the main response handler.  These non-response
handlers like Dispatch and Session do not need to create the
Apache2::Request object (I think...), so that is put off until 
the Response phase.

You should not use this module for anything that you're doing.

Pre-response phase handlers do not handle errors in the same way
that Apache2::Controller does.  If you get an error in a pre-response
phase, A2C cannot call your render class error() method, because
that stuff is not set up yet.  Instead, it spits the error to
the error log, logs the reason for the response code, and 
returns the response code.  This should get Apache to quit 
processing the chain of handlers... we'll see.

=head1 METHODS

=cut

use strict;
use warnings;
use English '-no_match_vars';

use Log::Log4perl qw(:easy);
use YAML::Syck;

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::Const -compile => qw( :common :http :methods );

use Apache2::Controller::X;
use Apache2::Controller::Const qw( @RANDCHARS $NOT_GOOD_CHARS );
use Apache2::Controller::Funk qw( log_bad_request_reason );

=head2 handler

handler() takes the request, creates an object using the 
child class name, runs the process() method, and handles errors.

=cut

sub handler : method {
    my ($class, $r) = @_;

    DEBUG("begin $class ->handler()");

    my ($handler, $http_status, $X) = ( );

    eval { 
        $handler = $class->new($r);
        $handler->process(); 
    };
    if ($X = Exception::Class->caught('Apache2::Controller::X')) {
        if ($X->isa('Apache2::Controller::X::Redirect')) {
            $http_status = Apache2::Const::REDIRECT;
            $r->err_headers_out->add(Location => "$X");
            DEBUG("redirecting to $X");
        }
        else {
            $http_status = $X->http_status || Apache2::Const::SERVER_ERROR;
            DEBUG("Caught an Apache2::Controller::X: $http_status");
            DEBUG(ref($X).": $X\n".($X->dump ? Dump($X->dump) : '').$X->trace());
        }
    }
    elsif ($X = $EVAL_ERROR) {
        DEBUG("Caught an unknown error: $X");
        $http_status = Apache2::Const::SERVER_ERROR;
    }

    if ($http_status) {
        DEBUG("Setting http-status to '$http_status'");
        $r->status($http_status);
    }

    if ($http_status && $http_status >= Apache2::Const::HTTP_BAD_REQUEST) {
        DEBUG("logging bad request");
        log_bad_request_reason($r, $X);
        return Apache2::Const::DONE;  # stop processing further handlers
    }
    elsif ($http_status && $http_status == Apache2::Const::REDIRECT) {
        return Apache2::Const::DONE;
    }
    else {
        DEBUG("returning OK");
        return Apache2::Const::OK;
    }
}

=head2 new

C<new()> creates an object of the child class and assigns the
C<<Apache2::RequestRec>> object to C<<$self->{r}>>.

If the parent class defines a method C<init()>, this will
be called at the end of object creation.

Unlike L<Apache2::Controller>, the handler object of other handlers
that use this package as a base do not create, delegate to and subclass
the L<Apache2::Request> object.  They just keep the original 
L<Apache2::RequestRec> object in C<<$self->{r}>>.

=cut

sub new {
    my ($class, $r) = @_;

    DEBUG("handler class is '$class', reqrec is '$r'");

    my $self = {
        r               => $r,
        class           => $class,
    };
    bless $self, $class;

    $self->init() if $self->can('init');

    return $self;
}

1;

=head1 SEE ALSO

L<Apache2::Controller::Dispatch>,
L<Apache2::Controller::Session>
L<Apache2::Controller>

=head1 AUTHOR

Mark Hedges, C<< <hedges at scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

