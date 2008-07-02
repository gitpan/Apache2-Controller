package Apache2::Controller::Dispatch;

=head1 NAME

Apache2::Controller::Dispatch - dispatch base class for Apache::Controller

=head1 SYNOPSIS

 # vhost.conf:
 PerlModule MyApp::Dispatch

 <Location />
     SetHandler modperl
     PerlInitHandler MyApp::Dispatch
 </Location>

 # lib/MyApp/Dispatch:

 package MyApp::Dispatch;

 use strict;
 use warnings FATAL => 'all';

 use base qw( Apache2::Controller::Dispatch::Simple );

 our %dispatch_map = (
     foo        => 'MyApp::C::Foo',
     bar        => 'MyApp::C::Bar',
     biz        => 'MyApp::C::Biz',
     'biz/baz'  => 'MyApp::C::Biz::Baz',
 );

 sub handler { Apache2::Controller::Dispatch::handler(@_) } # required

 1;
 
=head1 DESCRIPTION

C<Apache2::Controller::Dispatch> forms the base for the
PerlInitHandler module to dispatch incoming requests to
libraries based on their URL.

Natively, this does not try to figure out the appropriate
module using any complex magic.  Instead, you spell out the
uris under the root handler location and what controller
modules you want to handle paths under that URL.

You do not absolutely need to implement any methods in your dispatch
class.  Instead, use multiple bases that add features which
will be called by the C<process()> method in proper sequence.
Caveat: some of the other dispatch base modules, like 
Apache2::Controller::Session::Cookie require that you implement
certain methods, for example in that case, to access your database.

The handler subroutine that kicks up to Apache::Controller::Dispatch
is essential here, otherwise there is no way for that module to know
the class name of your dispatch module.

=cut

use strict;
#use warnings FATAL => 'all', NONFATAL => 'redefine';
use warnings FATAL => 'all';
use English '-no_match_vars';

use base qw( 
    Apache2::Controller::NonResponseBase 
    Apache2::Controller::Methods 
);

use Log::Log4perl qw(:easy);
use Readonly;

use YAML::Syck;

Readonly my $GENERATE_SID_TRIES => 20; # times to generate unique sid

use Apache2::RequestRec ();
use Apache2::Connection ();
use Apache2::RequestUtil ();
use Apache2::Const -compile => qw( :common :http :methods );

use Apache2::Controller::X;
use Apache2::Controller::Const qw( @RANDCHARS $NOT_GOOD_CHARS );
use Apache2::Controller::Funk qw( log_bad_request_reason );

=head1 METHODS

=head2 $handler->init()

You can limit HTTP methods in your child class:

 package MyApp::Dispatch;
 use base qw( Apache2::Controller::Dispatch );
 my @LIMIT_HTTP_METHODS = qw( GET POST ); # but not HEAD or PUT, etc

This gets processed by C<init()> which is run from 
C<Apache2::Controller::NonResponseBase> if the method is
available.

=cut

my %limit_http_methods = ();

sub init {
    my ($self) = @_;
    # figure out if the dispatch subclass limits some http methods
    # and cache this information.

    my $class = $self->{class};
    my $r     = $self->{r};

    if (!exists $limit_http_methods{$class}) {
        # init some package vars storing this information
        
        # what http methods are limited?  no entries is same as unlimited.
        my @limits = ( );
        eval '@limits = @'.$class.'::LIMIT_HTTP_METHODS; ';
        if (@limits) {
            my $bits = $r->allowed();
            eval '$bits = $bits | Apache2::Const::M_'.$_.';' for @limits;
            $limit_http_methods{$class} = {
                lookup  => { map {$_=>1} @limits },
                bits    => $bits,
            };
          # DEBUG(sub {"limit_http_methods:".Dump(\%limit_http_methods)});
        }
    }
    return;
}

=head2 $handler->process()

process() is the main guts of Apache2::Controller::Dispatch logic.
It calls $self->find_controller(), which is implemented in another
base class.  (See L<Apache2::Controller::Dispatch::Simple>.)  If that
works, then it creates an Apache2::Request object from $r, which will
supposedly parse the query string once for all further handlers that
create Apache2::Request objects.

=cut

sub process {
    my ($self) = @_;

    my $r       = $self->{r};
    my $class   = $self->{class};

    # limit http methods if limits are defined in parent class
    # this is GET, POST, PUT etc. of the http protocol
    if (exists $limit_http_methods{$class}) {
        my $http_method_number = $r->method_number();
        if  (   $http_method_number     # tests get method '0'
            &&  !exists $limit_http_methods{$class}{lookup}{$http_method_number}
            ) {
            $r->allowed( $r->allowed | $limit_http_methods{$class}{bits} );
            DEBUG("Method not allowed: $http_method_number");
            return Apache2::Const::HTTP_METHOD_NOT_ALLOWED;
        }
    }

    # find the controller module and method to dispatch the URI
    $self->find_controller();
    my $controller = $self->{controller} = $r->notes->{controller};
    DEBUG("found controller '$controller'");

    # push the handler for that class 
    # - this has to be the last thing it does in case an exception is thrown

    DEBUG("pushing PerlResponseHandler '$controller'");
    $r->push_handlers(PerlResponseHandler => "$controller"); # "" == lame but true

    DEBUG("Done with process()");
    
    return Apache2::Const::OK;
}

1;

=head1 EXAMPLE

 # configuration for <Location>:
 # PerlInitHandler MyApp::Dispatch

 package MyApp::Dispatch;
 use base qw( 
     Apache2::Controller::Dispatch
     Apache2::Controller::Dispatch::Simple
 );

 my @LIMIT_HTTP_METHODS = qw( GET );

 our %dispatch_map = (
     foo        => 'MyApp::C::Foo',
     bar        => 'MyApp::C::Bar',
     biz        => 'MyApp::C::Biz',
 );

 1;

=head1 SEE ALSO

L<Apache2::Controller::Dispatch::Simple>,
L<Apache2::Controller>

=head1 AUTHOR

Mark Hedges, C<< <hedges at scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

