package Apache2::Controller;

=head1 NAME

Apache2::Controller - framework for Apache2 handler apps

=head1 VERSION

Version 1.000.001 - FIRST RELEASE

=cut

use version;
our $VERSION = version->new('1.000.001');

=head1 SYNOPSIS

For Apache2 config file setup see L<Apache2::Controller::Dispatch>,
which sets a PerlResponseHandler of Apache::Controller, which
then instantiates your controller object and calls the chosen
method for the uri.
 
 package MyApp::C::Foo;
 use strict;
 use warnings FATAL => 'all';

 use base qw( Apache2::Controller );

 use Apache2::Const -compile => qw( :http );
 sub allowed_methods {qw( default bar baz )}

 # suppose '/foo' is the uri path dispatched to this controller
 # and your dispatch uses L<Apache2::Controller::Dispatch::Simple>

 # http://myapp.xyz/foo/
 sub default {
     my ($self) = @_;
     $self->content_type('text/plain');
     $self->print("Hello, world!\n");
     return Apache2::Const::HTTP_OK;
 }

 # http://myapp.xyz/foo/bar/biz/schnozz
 sub bar {
     my ($self, @path_args) = @_;             
     # @path_args is:
     #      qw( biz schnozz )
     #      @{ $self->{path_args} }
     #      @{ $self->pnotes->{path_args} }

     $self->content_type('text/html');
     $self->print(q{ <p>"WE ARE ALL KOSH"</p> });
     return Apache2::Const::HTTP_OK;
 }

 # http://myapp.xyz/foo/baz
 sub baz {
     my ($self) = @_;

     return Apache2::Const::HTTP_BAD_REQUEST 
        if $self->param('goo');         # inherits Apache2::Request

     return Apache2::Const::HTTP_FORBIDDEN 
        if $self->param('boz') ne 'noz';

     $self->content_type('text/plain'); # inherits Apache2::RequestRec
     $self->sendfile('/etc/passwd');    # inherits Apache2::RequestIO

     return Apache2::Const::HTTP_OK;
 }

 1;

You could implement a pretty nice REST interface, or any other kind
of HTTP-based API, by returning the appropriate HTTP status codes.
See L<Apache2::Controller::Refcard/status> for a list.

See L<Apache2::Controller::Render::Template> for an additional base
for your controller class to render HTML with L<Template> Toolkit.

=head1 DESCRIPTION

Apache2::Controller is a lightweight controller framework for 
object-oriented applications designed to run only under mod_perl 
children in high-performance Apache2 handler modules.  It features URL 
dispatch with flexible configuration, auth plugins, a cookie tracker
for Apache::Session, liberty for any storage models that work under mod_perl,
rendering using Template Toolkit or direct printing with Apache,
and base inheritance configuration allowing you to 
construct your applications as you need, without trying to be all things 
to all people or assimilate the world.  
It is intended as a framework for 
new applications specialized as Apache2 handlers, not as a means to 
absorb existing applications or to create portable code.  

Apache2::Controller subclasses Apache2::Request, and pulls in
methods from L<Apache2::RequestRec>, L<Apache2::RequestIO>, 
L<Apache2::RequestUtil>, L<Apache2::Log>, L<Apache2::Module>.

For using other Apache2 request extension methods, use 
another base class like 
L<Apache2::Controller::Upload> early in your C<use base> list, 
which will add the methods from L<Apache2::Upload> when the
L<Apache2::Request> object gets created.
L<Apache2::Controller::Uploads> is a second base module for controller 
modules to inherit from to allow file uploads and provide various handy 
file conversion routines, if you have the appropriate binaries 
installed.

L<Apache2::Controller::Render::Template> provides an easy way to
use Template Toolkit by default to render pages, selecting templates
from a directory structure that corresponds to your controller URI's.

Individual controller methods can specify plain text or other
content types and print directly through inherited L<Apache2::RequestIO> 
methods.

Instead of abstracting Rube Goldberg devices around the Apache2 mod_perl 
methods, it stays out 
of your way and lets you use any and all of them directly through 
C<$self> as you see fit.

Use L<Apache2::Controller::Dispatch> from your Apache2 config file to 
send various URI requests to your page view modules.  See the 
CONFIGURATION section below.  This features a standard mechanism for uri 
dispatch in L<Apache2::Controller::Dispatch::Simple> that does not try 
to figure out what modules are available, but 
simply requires you to provide a hash that maps from uri paths to 
controller modules.  Or, dispatch plugins can be created to implement
the dispatcher's find_controller() method in some other way, like
with a TRIE for big sites or using other algorithms.

L<Apache2::Controller> is the base module for each controller module. 
Your controller modules then contain a list of the method names which 
are allowed as uri paths under the controller.  Instead of implementing 
a complex scheme of subroutine attributes, you maintain a list, which 
also acts as your documentation in one place within the controller. This 
frees you to structure your controller module as you want to, with 
whatever other methods you choose to put in there.

=head1 DISPATCH OF URI TO CONTROLLER

You do not put Apache2::Controller or your subclass into the
Apache2 server configuration.  Instead you make a subclass
of L<Apache2::Controller::Dispatch> and use that as a
PerlInitHandler.  It will map a URI to an appropriate
Apache2::Controller subclass object and method and will
use C<<$r->push_handlers()>> if successful to push Apache2::Controller
onto the modperl handler stack.  See L<Apache2::Controller::Dispatch>
for more information and different types of URI dispatching.

=head1 OTHER REQUEST PHASE HANDLERS

Configure other handlers in your config file to set things up
before your Apache2::Controller runs.

Most of these handlers use L<Apache2::Controller::NonResponseBase>
as a base for the object, which usually does not need to
instantiate the L<Apache2::Request> object.
So if your subclass methods need acces to the
L<Apache2::RequestRec> object C<<$r>>, 
it is in C<<$self->{r}>>.

Some other request phase handlers register later-stage handlers,
for example to save the session or rollback the database 
transaction with C<PerlLogHandler>'s
after the connection output is complete.

The controller handler always returns your set HTTP status code
or OK (0) to Apache.  In general you return the status code
that you want to set, or return OK.  I don't know what happens
if you return DONE or DECLINED.  See L<Apache2::Const>
and L<Apache2::Controller::Refcard>.

Add handlers in your config file with your own modules which 
C<use base> to inherit from these classes as you need them:

=head2 PerlHeaderParserHandler Apache2::Controller::Session

C<<$r->pnotes->{session}>> fed from and stored to an 
L<Apache::Session> tied hash.  Pushes a PerlLogHandler
to save the session after the main controller returns OK.

See L<Apache2::Controller::Session>
and L<Apache2::Controller::Session::Cookie>.

=head2 PerlAuthenHandler Apache2::Controller::Authen::OpenID

Implements OpenID logins and redirects to your specified login 
controller by changing the dispatch selection on the fly.
When authorized, username is put in C<<$r->pnotes->{session}{username}>>
with a timestamp, and denies access after a set idle timeout.
Requires use of Apache2::Controller::Session.

UNIMPLEMENTED

See L<Apache2::Controller::Authen::OpenID>.

=head2 PerlAuthzHandler Apache2::Controller::Authz::Groups subclass

Subclass this handler to implement groups, and configure
by implementing routines that load config files or query 
a database.

UNIMPLEMENTED

See L<Apache2::Controller::Authz::Groups>.

=head1 Apache2::Controller RESPONSE PHASE HANDLER

Apache2::Controller is set as the PerlResponseHandler if 
the dispatch class finds a valid module and method for the request.
Your controller uses

=head2 SUBCLASS OF L<Apache2::Request>

Apache2::Controller is a subclass of L<Apache2::Request>,
which inherits the L<Apache2::RequestRec> object with most of
the modperl2 request extension libraries loaded during 
construction.  So you can call C<<$self->$methodname>> for any of
the methods associated with L<Apache2::Request>, 
L<Apache2::RequestRec> and some of their friends.  
Watch the log for warnings about redefined subroutines, or 
C<<use warnings FATAL => 'all'>> to keep yourself on the
right track.

 package MyApp::C::SomeURIController;
 # ...
 
 sub set_shipping_address {
    my ($self) = @_;

    # $self->param() is Apache::Request param():
    my ($shipto, $addr, $zip) 
        = map {
            my $detaint = "detaint_$_";
            $self->$detaint( $self->param($_) )
        } qw( shipto addr zip );
    # ...
 }

 sub detaint_shipto {   # ...
 sub detaint_addr   {   # ...
 sub detaint_zip    {   # ...

At any rate, your Apache2::Controller child object subclasses 
itself into Apache2::Request and delegates all those methods
to the internal hash value $self->{r}, which is the actual 
Apache2::Request object.
See L<Apache2::Request> about those gory details.  Whether 
you call C<< $self->$apache2_request_method >> or 
C<< $self->{r}->$apache2_request_method >> matters not,
you still ask the same object, so you might as well use
C<< $self->... >> to make it look clean.

=head1 RETURN VALUES

Your controller methods should use eval { } if necessary and
act accordingly, set the right things for C<Apache2::RequestRec> 
and return the right C<Apache2::Const/:http>.

In the event of an error, if you wish, use L<Apache2::Controller::X>
and throw one with field 'status' set to a valid HTTP return code.  
This lets you implement nice error templates if your controller uses 
L<Apache2::Controller::Render::Template> as a second base.
See L<ERRORS> below.

Success in the controller method normally should just return the
appropriate HTTP status code.  You can return HTTP_OK (200) if that
is what you mean, or it is the default status if you return OK (0).

Or, if you do C<< $self->status( Apache2::Const::HTTP_SOMETHING ) >>
and then just return, Apache2::Controller will not override the set status.

See L<Apache2::Controller::Refcard> for a list of HTTP return constants
and corresponding numbers and messages.

=head2 REDIRECTS, ETC.

For external redirects,
set C<< $self->err_headers_out->add(Location => 'http://foo.bar') >>
and return C<< $self->status(Apache2::Const::REDIRECT) >>.  C<< $self >>
is (delegates to) the L<Apache2::Request> object which inherits from 
L<Apache2::RequestRec> and friends.  You have access to everything
without dereferencing pointers, for instance, internal redirects
that process a new request within a subprocess of the current one.
(This dereferences C<< $self->{r} >> internally but it makes your
controller logic more simple and direct.)

Keep in mind that if you use other request phase processors that
push a C<PerlLogHandler> like 
L<Apache2::Controller::DBI::Connector> or
L<Apache2::Controller::Session>, those will still run.
So in the case of a redirect while you have an open transaction,
or where you do not want to save tied session changes when redirecting,
you should trap errors with C<< eval >> and deal with it accordingly.

You should also not fiddle with the connection by causing
Apache2 to close it prematurely, else these handlers may not
run synchronously before another request is received that
may have depended on their behavior.

=head1 ERRORS

If you decide to set an error status code, you can print your
own content and return that status code.

If you want to use error templates, 
barf L<Apache2::Controller::X> objects.  These print a stack trace
to the error log at the WARN level of L<Log::Log4perl> from
this module's namespace.  If errors crop up from
other A2C request phase handlers, try setting
WARN log level for L<Apache2::Controller::NonResponseBase>
or L<Apache2::Controller::NonResponseRequest>.

Also see L<Apache2::Controller::Render::Template>.

You can use or subclass L<Apache2::Controller::X>,
to use C<< a2cx() >>,
or you can throw your own exception objects,
or just C<< die() >>, or C<< croak() >>,
or set C<< $self->status >>, headers etc., possibly printing content, 
or return the appropriate status from your controller method.

See L<Apache2::Controller::X> for help on throwing exceptions
with HTTP status, data dumps, etc.

If your code does break, die or throw an exception, this is 
caught by Apache2::Controller.  If your controller module implements
an C<error()> method, for instance by use of the base
L<Apache2::Controller::Render::Template> which looks in
template_dir/errors/ for the appropriately named error template,
then C<$handler->error()> will be called passing the C<< $EVAL_ERROR >>
or exception as the first argument.

 package MyApp::C::Foo;
 use YAML::Syck;
 # ...
 sub error {
     my ($self, $X) = @_;
     $self->status( Apache2::Const::HTTP_BAD_REQUEST );
     $self->content_type('text/plain');
     $self->print("Take this job and shove it!\n", "\n", $X, "\n");
     if ($X->isa('Apache2::Controller::X')) {
        # usually you wouldn't show gory details to the user...
        $self->print(Dump($X->dump)) if $X->dump;
        $self->print($X->trace) if $X->trace;  
     }
 }

Of course, all exceptions are sent to the error log using
L<Log::Log4perl> DEBUG() before the handler completes, and
any refusal status greater or equal to 400 (HTTP_BAD_REQUEST) 
will be written to the access log with L<Apache2::Log> log_reason() 
using the first few characters of the error.

See L<Apache2::Controller::Session/ERRORS> for how to control
whether or not a session is saved.  Usually it is automatically
saved.  If you don't want it saved when you have an error
in your controller, you'll have to use C<<eval>> and then
set C<<$self->notes->{a2c_connection_aborted}>> before you return
the error code.

=head1 CONTROLLER CLOSURES

Apache2::Controller's package space structure lets you take advantage
of closures that access variables in your controller subclass
package space, which are cached by modperl in child processes
across independent web requests.  Be careful with that and use
Devel::Size to keep memory usage down.

=head1 CONTENT TYPE

Your controller should set content type with C<$self-E<gt>content_type($ct)>
to something specific if you need that.  Otherwise it will let
mod_perl set it to whatever it chooses when you start to print.
This is usually text/html.

=head1 LOGGING

Apache2::Controller uses L<Log::Log4perl>.  See that module
for information on how to set up a format file or statement.
For example, in a perl startup script called at Apache2 start time,
do something like:
 
 use Log::Log4perl; # 'Screen' is STDERR, which is error log
 my $logconf = q{
    log4perl.rootLogger=DEBUG, Screen
    log4perl.appender.Screen=Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.layout=PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern=%M [%L]: %m%n
 };
 Log::Log4perl->init(\$logconf);

These settings will be cloned to every modperl child on fork.

=head1 MVC

Apache2::Controller provides the controller, mainly.  
L<Apache2::Controller::Render::Template> is one example
of a view that can be used as a second base with
C<use base> in your controller module.  As for the Model
part of Model-View-Controller, Apache2::Controller leaves
that entirely up to you and does not force you to
wrap anything in an abstraction class.  

The C<handler()> subroutine is in your base class and your
controller modules will be running from memory in the mod_perl
child interpreter.  So,
you can use package namespace effectively to store data
that will persist in the mod_perl child across requests.

=head1 LOAD BALANCING

A2C does not have to load 
all site modules for every page handler, which could help with load-balancing
highly optimized handlers for specific URI's while having a universal
application installer.  

Picture if you will, a programming utopia in which all engineers
are respected, highly paid and content.  

You deploy the same Apache, the
same CPAN modules and your whole application package to every server,
and attach a url-generating subroutine to the L<Template|Template> stash
that puts in a different hostname when the URI is one of your
load-intensive functions.  

 <a href="[% myurl('/easy') %]">easy</a> "http://pony.x.y/easy"

 <a href="[% myurl('/hard') %]">hard</a> "http://packhorse.x.y/hard"

Web designers can be taught to use this function C<< myurl() >>, 
but system admins
maintain the map that it loads to figure out what servers to use.

Then the Apache2 config files on those
packhorse servers would pre-load only the subclassed controllers
that you needed, and redirect all other uri requests to the pony servers.

=cut

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use base qw( Apache2::Request Apache2::Controller::Methods );

use Readonly;
use Scalar::Util qw( blessed );
use Log::Log4perl qw(:easy);

use Template;
use YAML::Syck;
use Digest::SHA qw( sha224_base64 );
use URI;
use HTML::Entities;
use URI::Escape;
use HTTP::Status qw( status_message );
use Scalar::Util qw( looks_like_number );

use Apache2::Controller::X;
use Apache2::Controller::Funk qw( check_allowed_method log_bad_request_reason );

use Apache2::Request;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Log;
use Apache2::Module ();
use Apache2::Const -compile => qw( :common :http );

=head1 FUNCTIONS

=head2 new

 $handler = MyApp::C::ControllerSubclass->new( Apache2::RequestRec object )

This is called by handler() to create the Apache2::Controller object
via the module chosen by your L<Apache2::Controller::Dispatch> subclass.

If your controller defines local TEMP_DIR or POST_MAX or the
L<Apache2::Controller::Directives> A2C_TEMP_DIR or A2C_POST_MAX,
these will be applied as settings during construction of the
L<Apache2::Request> object from the L<Apache2::RequestRec> object.

=head3 subclassing new( )

If you need to do the same stuff every time a request
starts, you can override the constructor.

 package MyApp::InitController;
 sub new {
     my $self = SUPER::new(@_);
     $self->push_handlers(PerlCleanupHandler => sub {
         my ($r) = @_;
         my $dbh = $r->pnotes->{dbh};
         $dbh->rollback() unless $r->notes->{commit_success};
     });    # implements some convention that you set 'commit_success', say
     return $self;
 }

Similarly, to do something always at the end of every 
request, from within the dispatched PerlResponseHandler:

 package MyApp::DestroyController;
 use Devel::Size;
 use Log::Log4perl qw(:easy);
 my $MAX = 40 * 1024 * 1024;
 sub DESTROY {
     my ($self) = @_;
     my $size = total_size($self);  # whoo baby!
     INFO("size of $self->{class} is bigger than $MAX!") if $size > $MAX;
     return; # self is destroyed
 }

And your subclass is:

 package MyApp::Controller::Foo;
 use base qw( Apache2::Controller MyApp::InitController MyApp::DestroyController );

 # ...

See L<USING INHERITANCE> below for more tips.

=cut

my %temp_dirs  = ( );
my %post_maxes = ( );

sub new {
    my ($class, $r) = @_;

    DEBUG("new $class, reqrec is '$r'");

    my $self = {
        class       => $class,
        r           => $r,      
    };
    # populate r with Apache2::RequestRec obj so pnotes works
    # to get the directives for creating Apache2::Request obj

    bless $self, $class;

    DEBUG("creating Apache2::Request object");
    my $req = Apache2::Request->new(
        $r, $self->get_apache2_request_opts($class) 
    );
    DEBUG("request object is '$req'");

    $self->{r} = $req;  # Apache2::Request subclass automagic

    my $notes  = $req->notes;
    my $pnotes = $req->pnotes;

    my $method = $notes->{method};

    check_allowed_method($class => $method);  # double-check, i guess

    $self->{method}      = $method;
    $self->{path_args}   = $pnotes->{path_args};
    $self->{remote_addr} = $notes->{remote_addr};

    # don't instantiate the 'session' key of $self unless it's implemented
    # in some earlier stage of the apache lifecycle.
    my $session = $pnotes->{session};
    if ($session) {
        $self->{session} = $session;
        DEBUG(sub{"found and attached session to controller self:\n".Dump($session)});
        # this is the same reference as the pnotes reference still,
        # so the cleanup handler will find all changes made to it
    }

    DEBUG(sub { Dump({
        # for simple debugging, stringify objects, otherwise this can get huge
        map {($_ => defined $self->{$_} ? "$self->{$_}" : undef)} keys %$self 
    }) });

    return $self;
}

=head1 METHODS

Methods are also extended by 
L<Apache2::Controller::Methods|Apache2::Controller::Methods>.

=head2 handler

 # called from Apache, your subclass pushed to PerlResponseHandler
 # by your A2C dispatch handler:
 MyApp::Controller::Foo->handler( Apache2::RequestRec object )

The handler is pushed from an Apache2::Controller::Dispatch
subclass and via your dispatched subclass of Apache2::Controller.
It should not be set in the config file.  It looks
for the controller module name in C<< $r->notes->{controller} >>
and for the method name in C<< $r->notes->{method} >>.

Errors are intercepted and if the handler object was created
and implements an C<< $handler->error($exception) >> method 
then the exception will be passed as the argument.

An HTTP status code of HTTP_BAD_REQUEST or greater will 
cause log_reason to be called with a truncated error string
and the uri for recording in the access log.

=cut

my %supports_error_method = ( );

sub handler : method {
    my ($class, $r) = @_;
    return $class if !defined $r;

    my $method = $r->notes->{method};

    DEBUG("$class -> $method");

    my ($handler, $status, $X) = ( );
    eval {

        $handler = $class->new($r);
        $method  = $handler->{method};

        DEBUG("executing $class -> $method()");
        my $args = $r->pnotes->{path_args} || [];
        $status = $handler->$method(@{$args});
        $status = $handler->status() if !defined $status;

        if (defined $status) {
            if (ref $status || !looks_like_number($status)) {
                a2cx message => "Controller returned or set non-numeric status",
                    status  => Apache2::Const::SERVER_ERROR,
                    dump    => { controller_set_status => $status };
            }
            elsif ($status < 0) {
                a2cx "controller must set http status >= 0";
            }
        }

    };
    if ($X = $EVAL_ERROR) {
        my $ref = ref($X);

        $status 
          = $ref && blessed($X) && $X->can('status') 
                             ? ($X->status || Apache2::Const::SERVER_ERROR)
          : !defined $status                ? Apache2::Const::SERVER_ERROR
          : !looks_like_number($status)     ? Apache2::Const::SERVER_ERROR
          : $status == Apache2::Const::OK   ? Apache2::Const::HTTP_OK
          : Apache2::Const::SERVER_ERROR;

        # if appropriate and able to call self->error(), do that now
        if ($handler && !$r->notes->{use_standard_errors}) {

            eval {
                if (exists $supports_error_method{$class}) {
                    $handler->error($X);
                } 
                elsif ($class->can('error')) {
                    $handler->error($X); 
                }
            };
            $X = Exception::Class->caught('Apache2::Controller::X')
                || $EVAL_ERROR 
                || $X;
        }

        # now decide how to output debugging log:
        if (ref($X) && $X->isa('Apache2::Controller::X')) {
            WARN(sub {
                ref($X).": $X\n".($X->dump ? Dump($X->dump) : '').$X->trace()
            });
        }
        else {
            WARN("Caught an unknown error: $X");
        }
    }

    DEBUG("done with handler processing...");
    DEBUG(sub {
        my $ctype = $r->content_type();
        "content type is ".($ctype || '[undef]');
    });
    
    $r->status($status) if $status;

    DEBUG(sub { 
        my $stat  = defined $status ? $status : '';
        my $sline = $r->status_line() || '[none]';
        my $smsg  
            = defined $status 
            ? (status_message($status) || '[no msg]') 
            : 'N/A';
        my $debugstatus = defined $status ? $status : '[status not defined]';
        "status: $debugstatus ($smsg); status_line='$sline'";
    });

    if (!defined $status) {
        return Apache2::Const::OK;
    }
    elsif ($status >= Apache2::Const::HTTP_BAD_REQUEST) {
        # if status is an error, file error (possibly truncated) as a 
        # log_reason in the access log for why this request was denied.
        # (is this desirable?)
        log_bad_request_reason($r, $X);
        $r->status_line("$status ".status_message($status)) 
            if !$r->status_line;
        return $status;
    }
    else {
        return $status == Apache2::Const::HTTP_OK
            ? Apache2::Const::OK
            : $status;
    }

    # supposedly you can return the http status, but it doesn't work right
    # if you return HTTP_OK.  shouldn't it?
}

=head1 USING INHERITANCE

There is no need for a predefined sequence of start-up or clean-up
routines that Apache2::Controller would have to check for in your
controller module.  

Instead, you use inheritance to streamline your code and share
common pieces, like in L<subclassing new( )> above.

If your methods need to do cleanup after finishing,
for example,
they should add a line to call a shared cleanup method.

 package MyApp::Cleanup;
 sub cleanup {
     my ($self) = @_;
     # ...
 }

 package MyApp::C::Foo;
 use base qw( Apache2::Controller MyApp::Cleanup );
 sub allowed_methods {qw( foo bar )}

 sub foo {
     # ...
     $self->cleanup();
     return;
 }

 sub bar {
     # ...
     $self->cleanup();
     return;
 }

Or better yet...

 package MyApp::Cleanup;

There is no need for a predefined method sequence that
tries to run for each request, because Apache2 already
provides a robust abstraction of the request lifecycle
with many stages for which you can register handler subroutines.
If you can wrap your head around it, inheritance provides many 
solutions to problems for which elaborate measures are commonly 
re-invented.  For example if you wanted cleanup done the same way every 
time without having to remember that C<< $self->cleanup() >> line 
for each new
method, overload the constructor as per L<subclassing new( )> above 
and register a PerlCleanupHandler for every request instead.

Otherwise the framework ends up doing a lot of work every time
to ask, "did they implement this?  did they implement that?"
and that gets in your way, or you have to write those routines
every time even if they don't do anything, or whatever.  Bleah.
Implement what you want to implement from the controller methods.
The framework won't provide you with any more structure.

=head1 EXAMPLES

Browse the source package from CPAN
and check out t/lib/* and t/conf/extra.conf.last.in.

=head1 SEE ALSO

L<Apache2::Controller::Dispatch>

L<Apache2::Controller::Uploads>

L<Apache2::Controller::Session>

L<Apache2::Controller::DBI::Connector>

L<Apache2::Controller::Auth::OpenID>

L<Apache2::Controller::X>

L<Apache2::Controller::Refcard>

L<Apache2::Controller::Funk>

L<Apache2::RequestRec> and friends

L<Apache2::Request>

L<http://perl.apache.org>

=head1 AUTHOR

Mark Hedges, C<hedges +(a t)- scriptdolphin.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Mark Hedges.  CPAN: markle

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 


=cut

1;
