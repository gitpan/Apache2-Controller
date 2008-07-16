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

 1;
 
=head1 DESCRIPTION

C<Apache2::Controller::Dispatch> forms the base for the
PerlInitHandler module to dispatch incoming requests to
libraries based on their URL.

You don't use this module.  You use one of its subclasses
as a base for your dispatch module.

=for comment

Natively, this does not try to figure out the appropriate
module using any complex magic.  Instead, you spell out the
uris under the root handler location and what controller
modules you want to handle paths under that URL, using the
C<<A2CController>> directive.

(future implementation

=cut

=head1 SUBCLASSES

Subclasses of this module implement C<<find_controller()>>
in different ways, usually interpreting the URI from a
hash called C<<%dispatch_map>> in your subclass.

See L<Apache2::Controller::Dispatch::Simple> and
L<Apache2::Controller::Dispatch::HashTree> for other
dispatch possibilities.

Any implementation of find_controller() should throw an 
L<Apache2::Controller::X> with http => Apache2::Const::NOT_FOUND in the
event that the detected method selected does not appear in the list of
C<@ALLOWED_METHODS> in the controller module.  
See L<Apache2::Controller::Funk/check_allowed_method>

Successful run of find_controller() should result in four items of
data being set in request->notes and request->pnotes:

=over 4

=item notes->{relative_uri} = matching part of uri relative to location

This is the uri relative to the location. For example,
if the dispatch module is the init handler in a C<< <Location /subdir> >>
config block, then for /subdir/foo/bar/biz/zip in this example code,
relative_uri should be 'foo/bar' because this is the key of %dispatch_map
that was matched.  /subdir/foo/bar is the 'virtual directory.'

If there is no relative uri, for example if the uri requested was /subdir
and this is the same as the location, then C<notes->{relative_uri}> would be set to 
the empty string.

=item notes->{controller} = selected package name

This should be the name of an Apache2::Controller subclass selected
for dispatch.

=item notes->{method} = method name in controller to process the uri

This is the name of the method of the controller to use for this request.

=item pnotes->{path_args} = [ remaining path_info ]

The remaining 'virtual directory' arguments of the uri.
In the example above for notes->{relative_uri}, this is [ 'biz', 'zip' ].

=back

@path_args is the array of remaining elements.  For example if your
dispatch map contains the URI 'foo', and the incoming URI was '/foo/bar/baz',
then $r->pnotes->{path_args} should be ['bar', 'baz'] before returning.



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

    if (!exists $limit_http_methods{$class}) {
        # init some package vars storing this information
        
        # what http methods are limited?  no entries is same as unlimited.
        my @limits = ( );
        eval '@limits = @'.$class.'::LIMIT_HTTP_METHODS; ';
        if (@limits) {
            my $bits = $self->{r}->allowed();
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

=head2 get_dispatch_map

Get the cached %dispatch_map of the dispatch handler object's class.
Caches hashes here in parent package space and checks with C<<exists>>.

=cut

my %dispatch_maps = ( );
sub get_dispatch_map {
    my ($self) = @_;
    my $class = $self->{class};
    return $dispatch_maps{$class} if exists $dispatch_maps{$class};
    my $dispatch_map;
    eval '$dispatch_map = \%'.$class.'::dispatch_map';
    $dispatch_maps{$class} = $dispatch_map;
    DEBUG(sub{"dispatch_maps:".Dump(\%dispatch_maps)});
    return $dispatch_map;
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

