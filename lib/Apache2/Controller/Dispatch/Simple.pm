package Apache2::Controller::Dispatch::Simple;

=head1 NAME

Apache2::Controller::Dispatch::Simple - simple dispatch mechanism for A2C

=head1 SYNOPSIS

 <Location /subdir>
     SetHandler modperl
     PerlOptions +SetupEnv
     PerlInitHandler MyApp::Dispatch
 </Location>

 # lib/MyApp::Dispatch:

 package MyApp::Dispatch;
 use base qw(
     Apache2::Controller::Dispatch
     Apache2::Controller::Dispatch::Simple
 );

 our %dispatch_map = (
     foo            => 'MyApp::C::Foo',
     'foo/bar'      => 'MyApp::C::Foo::Bar',
 );

 sub handler { Apache2::Controller::Dispatch::handler(shift, __PACKAGE__) }

=head1 DESCRIPTION

Implements find_controller() for Apache2::Controller::Dispatch with
a simple URI-to-controller module mapping.  Your URI's are the keys
of the %dispatch_map hash in your base package, and the values are
the Apache2::Controller modules to which those URI's should be dispatched.

This dispatches URI's in a case-insensitive fashion.  It searches from
longest known path to shortest.  For a site with many controllers and
paths, a trie could possibly be more efficient.  Consider that implementation
for another Dispatch plugin module.

Any implementation of find_controller() should throw an 
L<Apache2::Controller::X> with http => Apache2::Const::NOT_FOUND in the
event that the detected method selected does not appear in the list of
C<@ALLOWED_METHODS> in the controller module.  
See L<Apache2::Controller::Funk/check_allowed_method( )>

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

=head1 SEE ALSO

Apache2::Controller::Dispatch

=cut

use strict;
use warnings;
use English '-no_match_vars';

use Apache2::Controller::X;
use Apache2::Controller::Funk qw( controller_allows_method check_allowed_method );

use Log::Log4perl qw(:easy);
use YAML::Syck;

my %dispatch_maps   = ( );
my %search_uris     = ( );
my %uri_lengths     = ( );

# return, for the class, the dispatch_map hash, uri_length map, and search uri list
sub get_class_info {
    my ($self) = @_;
    my $class = $self->{class};
    my ($dispatch_map, $uri_length_map, $search_uri_list) = ();
    if (exists $dispatch_maps{$class}) {
        $dispatch_map       = $dispatch_maps{$class};
        $uri_length_map     = $uri_lengths{$class};
        $search_uri_list    = $search_uris{$class};
    }
    else {
        # find the dispatch map in parent class if not yet cached in this module
        eval '$dispatch_map = \%'.$self->{class}.'::dispatch_map';
        $dispatch_maps{$class} = $dispatch_map;

        # search dispatch uri keys from longest to shortest
        my @uris = keys %{$dispatch_map};
        Apache2::Controller::X->throw(
            "Upper case characters not allowed in $class dispatch_map "
            ."when using ".__PACKAGE__." to dispatch URIs."
        ) if grep m/ \p{IsUpper} /mxs, @uris;

        $uri_length_map = $uri_lengths{$class} = { };
        $uri_length_map->{$_} = length $_ for @uris;

        $search_uri_list = $search_uris{$class} = [ 
            sort { $uri_length_map->{$b} <=> $uri_length_map->{$a} } @uris 
        ];

        DEBUG(sub{"dispatch_maps:".Dump(\%dispatch_maps)});
        DEBUG(sub{"search_uris:".Dump(\%search_uris)});
        DEBUG(sub{"uri_lengths:".Dump(\%uri_lengths)});
    }
    return ($dispatch_map, $uri_length_map, $search_uri_list);
}

sub find_controller {
    my ($self) = @_;

    my $class = $self->{class};

    my ($dispatch_map, $uri_length_map, $search_uri_list) 
        = $self->get_class_info();

    # figure out what most-specific path matches this URI.
    my $r = $self->{r};
    my $location = $r->location();
    my $uri = $r->uri();
    DEBUG(sub{Dump({
        uri             => $uri,
        location        => $location,
    })});
    DEBUG(sub{Dump(\%ENV)});

    $uri = substr $uri, length $location;

    DEBUG("uri becomes '$uri'");

    if ($uri) {
        # trim duplicate /'s
        $uri =~ s{ /{2,} }{/}mxsg;

        # chop leading /
        $uri = substr($uri, 1) if substr($uri, 0, 1) eq '/';
    }
    else {
        # 'default' is the default URI for top-level requests
        $uri = 'default';
    }
    my $uri_len = length $uri;
    my $uri_lc  = lc $uri;

    my ($controller, $method, $relative_uri) = ();
    my @path_args = ();

    SEARCH_URI:
    for my $search_uri (
        grep $uri_length_map->{$_} <= $uri_len, @{$search_uri_list} 
        ) {
        my $len = $uri_length_map->{$search_uri};
        my $fragment = substr $uri_lc, 0, $len;
        DEBUG("search_uri '$search_uri', len $len, fragment '$fragment'");
        if ($fragment eq $search_uri) {

            DEBUG("fragment match found: '$fragment'");

            # if next character in URI is not / or end of string, this is not it,
            # only a partial (/foo/barrybonds/stats should not match /foo/bar)
            my $next_char = substr $uri, $len, 1;
            if ($next_char && $next_char ne '/') {
                DEBUG("only partial match.  next SEARCH_URI...");
                next SEARCH_URI;
            }

            $controller = $dispatch_map->{$search_uri} 
                || Apache2::Controller::X->throw(
                    "No controller assigned in $class dispatch map for $search_uri."
                );
            
            # extract the method and the rest of the path args from the uri
            if ($next_char) {
                my $rest_of_uri = substr $uri, $len + 1;
                my $first_arg;
                ($first_arg, @path_args) = split '/', $rest_of_uri;

                DEBUG("rest_of_uri '$rest_of_uri'");
                DEBUG("first_arg '$first_arg'");
                DEBUG(sub {Dump(\@path_args)});

                # if the first field in the rest of the uri is a valid method,
                # assume that is the thing to use.
                if  (   defined $first_arg 
                    &&  controller_allows_method($controller, $first_arg)
                    ) {
                    $method = $first_arg;
                }
                # else use the 'default' method
                else {
                    $method = 'default';
                    unshift @path_args, $first_arg if defined $first_arg;
                }
                $relative_uri = $search_uri;
            }
            last SEARCH_URI;
        }
    }

    DEBUG($controller ? "Found controller '$controller'" : "no controller found");
    DEBUG($method     ? "Found method '$method'"         : "no method found");

    if (!$controller) {
        DEBUG("No controller found.  Using default module from dispatch map.");
        $controller = $dispatch_map->{default} || Apache2::Controller::X->throw(
            "No 'default' controller assigned in $class dispatch map."
        );
        my $first_arg;
        ($first_arg, @path_args) = split '/', $uri;
        if (controller_allows_method($controller => $first_arg)) {
            $method = $first_arg;
        }
        else {
            $method = 'default';
            unshift @path_args, $first_arg;
        }
    }

    Apache2::Controller::X->throw("No controller module found.") if !$controller;

    $method       ||= 'default';
    $relative_uri ||= '';

    check_allowed_method($controller, $method);

    DEBUG(sub {Dump({
        apache_location     => $r->location(),
        apache_uri          => $r->uri(),
        my_uri              => $uri,
        controller          => $controller,
        method              => $method,
        path_args           => \@path_args,
        relative_uri        => $relative_uri,
    })});

    $r->notes->{method} = $method;
    $r->notes->{relative_uri} = $relative_uri;
    $r->notes->{controller} = $controller;
    $r->pnotes->{path_args} = \@path_args;

    return $controller;
}

1;
