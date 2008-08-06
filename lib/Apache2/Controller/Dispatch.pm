package Apache2::Controller::Dispatch;

=head1 NAME

Apache2::Controller::Dispatch - dispatch base class for Apache::Controller

=head1 VERSION

Version 0.110.000 - BETA TESTING (ALPHA?)

=cut

our $VERSION = version->new('0.110.000');

=head1 SYNOPSIS

Synopsis examples use L<Apache2::Controller::Dispatch::Simple>,
but you may want to check out L<Apache2::Controller::Dispatch::HashTree>
or write your own.  All use the C<< A2C_Dispatch_Map >> directive,
but the hash structure differs between subclasses.

=head2 EASY WAY

This only works if you have one website on the whole server (under forked mpm)
because the intepreter only loads the module once and then it won't
load another dispatch map for other uri's.  

 # vhost.conf:
 <Location />
     SetHandler modperl
     A2C_Dispatch_Map   /path/to/yaml/syck/dispatch/hash/file.yaml
     PerlInitHandler    Apache2::Controller::Dispatch::Simple
 </Location>

=head2 NORMAL WAY

The normal way supports many separate dispatch maps on a server,
but each application must subclass a dispatch class, even if it
has no methods.

 # vhost.conf:
 PerlLoadModule MyApp::Dispatch;
 <Location />
     SetHandler modperl
     A2C_Dispatch_Map   /etc/myapp/dispatch.yaml
     PerlInitHandler    MyApp::Dispatch
 </Location>

 # /etc/myapp/dispatch.yaml:
 foo:       MyApp::Controller::Foo
 bar:       MyApp::Controller::Bar
 biz:       MyApp::C::Biz
 'biz/baz': MyApp::Controller::Biz::Baz

 # lib/MyApp/Dispatch.pm:
 package MyApp::Dispatch;
 use base qw( Apache2::Controller::Dispatch::Simple );
 1;

=head2 HARD WAY

 # vhost.conf:
 PerlModule MyApp::Dispatch

 <Location />
     SetHandler modperl
     PerlInitHandler MyApp::Dispatch
 </Location>

 # lib/MyApp/Dispatch.pm:

 package MyApp::Dispatch;

 use strict;
 use warnings FATAL => 'all';

 use base qw( Apache2::Controller::Dispatch::Simple );

 # return a hash reference from dispatch_map()
 sub dispatch_map { return {
     foo        => 'MyApp::C::Foo',
     bar        => 'MyApp::C::Bar',
     biz        => 'MyApp::C::Biz',
     'biz/baz'  => 'MyApp::C::Biz::Baz',
 } }

 # or use directive A2C_Dispatch_Map to refer to a YAML file.

 1;
 
=head1 DESCRIPTION

C<Apache2::Controller::Dispatch> forms the base for the
PerlInitHandler module to dispatch incoming requests to
libraries based on their URL.

You don't use this module.  You use one of its subclasses
as a base for your dispatch module.

=head1 WHY A MAP?

Natively, this does not try to figure out the appropriate
module using any complex magic.  Instead, you spell out the
uris under the handler location and what controller
modules you want to handle paths under that URL, using a
directive. (L<Apache2::Controller::Directives/A2C_Dispatch_Map>)

The trouble with automatic controller module detectors is
that parsing the URI and doing C<< eval "use lib $blah" >>
up through the URI path is that is computationally expensive.

Maintaining a URI map file is not that difficult and also is
convenient because you can move libraries around, point different
URI's to the same controller library, etc.  For example to bring
part of your site off-line and see 'under construction', create
a controller to print the right message, change all the uri's
in the map and bump the server.  

(Can I trap a signal so it 
clears and reloads map files if Apache2 is HUP'd?  That would be cool.
Or a timeout that would cause children to reload the file.)

Different dispatch types use different structure in the
map, but it is conceptually the same.  The structure is
loaded into memory and then the uri can be parsed very
quickly to locate the correct controller.

=head1 SUBCLASSES

Subclasses of this module implement C<< find_controller() >>
in different ways, usually interpreting the URI from a
hash reference returned by C<< dispatch_map() >> in your subclass.
Or, if you provide the directive C<< A2C_Dispatch_Map >> to specify
a map file, this module will load it with L<YAML::Syck/LoadFile>.

See L<Apache2::Controller::Dispatch::Simple> and
L<Apache2::Controller::Dispatch::HashTree> for other
dispatch possibilities.

Any implementation of find_controller() should throw an 
L<Apache2::Controller::X> with status C<< Apache2::Const::NOT_FOUND >>
in the
event that the detected method selected does not appear in the list of
C<< allowed_methods() >> in the controller module.  
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

=head2 dispatch_map

The base class method relies on having directive C<< A2C_Dispatch_Map >>.
This loads a L<YAML::Syck> file at server startup for every instance
of the directive.  This is your best bet if you want to use a file,
because the file will be loaded only once, instead of every time a 
mod_perl child process spawns.

If you want to return a hash yourself, overload this in a 
dispatch subclass.

=cut

sub dispatch_map {
    my ($self) = @_;
    return $self->get_directive('A2C_Dispatch_Map')
        || Apache2::Controller::X->throw("No directive A2C_Dispatch_Map");
}

=head2 get_dispatch_map

Get the cached C<< \%dispatch_map >> of the dispatch handler object's class.
Caches references here in parent package space and checks with C<< exists >>.

In your dispatch subclass, you define C<< dispatch_map() >> which 
returns a hash reference of the dispatch map. 

=cut

my %dispatch_maps = ( );
sub get_dispatch_map {
    my ($self) = @_;
    my $class = $self->{class};
    return $dispatch_maps{$class} if exists $dispatch_maps{$class};

    my $dispatch_map = $self->dispatch_map();

    Apache2::Controller::X->throw("No dispatch_map() in $class") if !$dispatch_map;

    my $ref = ref $dispatch_map;
    Apache2::Controller::X->throw("Bad dispatch_map() in $class") 
        if !defined $ref || $ref ne 'HASH';

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

 sub dispatch_map { {                   # return a hash reference
     foo        => 'MyApp::C::Foo',
     bar        => 'MyApp::C::Bar',
     biz        => 'MyApp::C::Biz',
 } }

 1;

=head1 SEE ALSO

L<Apache2::Controller::Dispatch::HashTree>

L<Apache2::Controller::Dispatch::Simple>

L<Apache2::Controller>

=head1 AUTHOR

Mark Hedges, C<< <hedges at scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

