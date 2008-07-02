package Apache2::Controller::Session;

=head1 NAME

Apache2::Controller::Session - Apache2::Controller PerlHeaderParserHandler for Apache::Session

=head1 SYNOPSIS

Set your A2C session subclass as a C<PerlHeaderParserHandler>.

This example assumes use of L<Apache2::Controller::Session::Cookie>.

 # cookies will get path => /somewhere
 <Location /somewhere>

     # see Apache2::Controller::Dispatch for dispatch subclass info
     PerlInitHandler         MyApp::Dispatch

     PerlSetVar  A2CSessionCookieName    myappsessid
     PerlSetVar  A2CSessionClass         Apache::Session::MySQL

     PerlHeaderParserHandler MyApp::Session
 </Location>

In controllers, tied session hash is C<< $r->pnotes->{session} >>.

In this example above, you implement C<get_options()> 
in your session subclass to return the options hashref to
C<tie()> for L<Apache::Session::MySQL>.  

If you do not implement get_options(), it will try to create
directories to use Apache::Session::File
using C<< /tmp/a2c_sessions/<request hostname>/ >>
and C<< /var/lock/a2c_sessions/<request hostname> >>

=head1 DESCRIPTION

Your session module uses an Apache2::Controller::Session tracker module 
as a base and you specify your L<Apache::Session> options either as
config variables or by implementing a method C<<getoptions()>>.

Instead of having a bunch of different options for all the different
L<Apache::Session> types, it's easier for me to make you provide
a method C<session_options()> in your subclass that will return a 
has of the appropriate options for your chosen session store.

=head2 CONFIG ALTERNATIVE 1: directives or PerlSetVar variables

If you do not implement a special C<getoptions()> method
or use settings other than these, these are the default:
 
 <Location /elsewhere>
     PerlHeaderParserHandler MyApp::ApacheSessionFile

     # until directives work, use this PerlSetVar syntax:
     PerlSetVar A2CSessionClass Apache::Session::File
     PerlSetVar A2CSessionOptions "Directory /tmp/sessions LockDirectory /var/lock/sessions"

     # under future fixed Apache2::Controller::Directives directives
     A2CSessionClass    Apache::Session::File
     A2CSessionOptions  Directory       /tmp/sessions 
     A2CSessionOptions  LockDirectory   /var/lock/sessions
 </Location>

Until directives work and the kludgey PerlSetVar syntax goes away,
spaces are not allowed in the argument values.  Warning!  
The kludgey PerlSetVar syntax will go away when
directives work properly.

=head2 CONFIG ALTERNATIVE 2: C<< YourApp::YourSessionClass->get_options() >>

Implement C<get_options()> in your subclass to return the final options 
hashref for your L<Apache::Session> session type.

For example, if your app uses DBIx::Class, maybe you want to
go ahead and init your schema so you can get the database 
handle directly and pass that to your session class.
or if you use Apache::DBI, connect and put it in pnotes
to save for your own use later.

Here's a code example for Location /somewhere above:

 package MyApp::Session;
 use strict;
 use warnings FATAL => 'all';

 use base qw( Apache2::Controller::Session::Cookie );

 use English '-no_match_vars';
 use Apache2::Controller::X;

 sub get_options {
     my ($self) = @_;  # $self inherits Apache2::Controller::Session,
                       # Apache2::Controller::Session::Cookie,
                       # Apache2::Request, Apache2::RequestRec, etc...
     eval {
         $self->pnotes->{dbh} ||= DBI->connect(
             'dbi:mysql:database=myapp;host=mydbhost';
             'myuser', 'mypassword'
         );
     };
     Apache2::Controller::X->throw("cannot connect to DB: $EVAL_ERROR")
         if $EVAL_ERROR;
     
     my $dbh = $self->pnotes->{dbh};    # save handle for later use
                                        # in controllers, etc.

     return {
         Handle      => $dbh,
         LockHandle  => $dbh,
     };
 }

If you do it this way or use Apache::DBI, 
be careful about transactions.  See L<DATABASE TRANSACTION SAFETY> below.

 # ...

In your controller module, access the session in C<< $self->pnotes->{session} >>.
 
 package MyApp::Controller::SomeWhere::Overtherainbow;
 # ...
 sub default {
     my ($self) = @_;

     my $session = $self->pnotes->{session};
     $session->{foo} = 'bar';

     # session will be saved by a PerlCleanupHandler
     # that was automatically pushed by Apache2::Controller::Session

     # and in my example

     return Apache2::Const::HTTP_OK;
 }

=head1 DATABASE TRANSACTION SAFETY 

When this handler runs, it ties the session into a special
hash that it keeps internally, and loads a copy into
C<< $r->pnotes->{session} >>.  So, modifying the session hash
is fine, as long as you do not dereference it, or as long
as you save your changes back to C<< $r->pnotes->{session} >>.

No changes are auto-committed.  The one in pnotes is
copied back into the tied session hash in a C<PerlCleanupHandler>,
after the server finishes output and closes
the connection to the client.  If the connection is detected
to be aborted in the C<PerlLogHandler> phase, changes are NOT 
saved into the session object in the C<PerlCleanupHandler> phase.

If you implemented C<get_options()> as per above and decided
to save your $dbh for later use in your controllers, feel free
to start transactions and use them normally.  Just make sure you
use L<perlfunc/eval> correctly and roll back or commit your
transactions. 

If you decide to push a C<PerlCleanupHandler> to roll back
transactions for broken connections or something, be aware
that this handler pushes a cleanup handler closure that
saves the copy in pnotes back into the tied hash.
So, depending on what order you want, whether you want
to save the session before or after your database cleanup handler,
you may have to re-order the C<PerlCleanupHandler> stack with
L<Apache2::RequestUtil/get_handlers> and C<set_handlers()>.

=head1 IMPLEMENTING TRACKER SUBCLASSES

See L<Apache2::Controller::Session::Cookie> for how to implement
a custom tracker subclass.  This implements C<$sid = get_session_id()> 
which gets a session id from a cookie, and C<set_session_id($sid)> 
which sets the session id in the cookie.

Perhaps some custom tracker subclass would implement
C<get_session_id()> to get the session_id out of the request 
query params, and C<set_session_id()> would push a C<PerlOutputFilterHandler>
to post-process all other handler output and append the session id param
onto any url links that refer to our site.  That would be cool...
release your own plug-in.
If you wanted to do it with combined cookies and url params in 
this way you could 
overload C<get_session_id()> and C<set_session_id()>, etc. etc.

=head1 COOKIES

L<Apache2::Controller> itself implements its own C<handler()> subroutine,
but other A2C handler modules C<<use base>> 
L<Apache2::Controller::NonResponseBase>.

For the most part the other A2C handlers do not need to construct
the L<Apache2::Request> object, but this one constructs it to
get at the cookies with L<Apache2::Cookie>.

It puts the results of C<<Apache2::Cookie::Jar->new()>> into 
C<<$r->pnotes->{cookie_jar}>>,
or uses the ones there if it finds them already captured.  See
L<Apache2::Controller::Methods/get_cookie_jar>.  Maybe.

=head1 ERRORS

C<<Apache2::Controller::Session>> will throw an error exception if the
session setup encounters an error.  

If the session should not be saved in the event your 
L<Apache2::Controller> controller subroutine traps an C<<$EVAL_ERROR>>,
then your controller should set boolean flag 
C<<$r->notes->{connection_closed}>>

=head1 METHODS

=cut

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use base qw( 
    Apache2::Controller::NonResponseBase 
    Apache2::Controller::Methods 
);

use YAML::Syck;
use Log::Log4perl qw(:easy);

use Apache2::RequestUtil ();

use Apache2::Controller::X;

=head2 process

The C<process()> method
attaches or creates a session, and pushes a PerlCleanupHandler
closure to save the session after the end of the request.

It sets the session id cookie
with an expiration that you set in your subclass as C<our $expiration = ...>
in a format that is passed to Apache2::Cookie.  (i.e. '3M', '2D', etc.)
Don't set that if you want them to expire at the end of the
browser session.

=cut

my %used;   # i feel used!

sub process {
    my ($self) = @_;
    my $r = $self->{r};

    my $session_id = $self->get_session_id();
    DEBUG("processing session: ".($session_id ? $session_id : '[new session]'));

    my $directives = $self->get_directives();
    my $class = $directives->{A2CSessionClass} || 'Apache::Session::File';
    DEBUG("using session class $class");

    do { 
        eval "use $class;"; 
        Apache2::Controller::X->throw($EVAL_ERROR) if $EVAL_ERROR;
        $used{$class}++;
    } if !exists $used{$class};

    my $options = $self->get_options(); 
        # (use $directives->{A2CSessionOptions} when they work)
    DEBUG(sub{"Creating session with options:\n".Dump($options)});

    my %tied_session = ();
    my $tieobj = undef;
    eval { 
        tie %tied_session, $class, $session_id, $options;
        DEBUG('Finished tie.');
        $tieobj = tied(%tied_session);
        DEBUG(sub{'Session is '.($tieobj ? 'tied' : 'not tied')});
    };
    Apache2::Controller::X->throw($EVAL_ERROR)      if $EVAL_ERROR;
    Apache2::Controller::X->throw("no session_id")  if !$tied_session{_session_id};
    Apache2::Controller::X->throw("no tied obj")    if !defined $tieobj;
    Apache2::Controller::X->throw("session_id mismatch") 
        if defined $session_id && $session_id ne $tied_session{_session_id};

    # set the session id in the tracker, however that works
    $session_id ||= $tied_session{_session_id};
    DEBUG(sub {"session_id is ".(defined $session_id ? "'$session_id'" : '[undef]') });

    $self->set_session_id($session_id);

    my %session_copy = (%tied_session);
    $r->pnotes->{session} = \%session_copy;
    $r->pnotes->{_tied_session} = \%tied_session;

    DEBUG("ref of real tied_session is '".\%tied_session."'");

    # push state detection handler to last phase that connection is open,
    # since the connection gets closed before PerlCleanupHandler
    my $helperdetect 
        = 'Apache2::Controller::HelpingHandlers::Log::DetectAbortedConnection';
    DEBUG("Pushing $helperdetect");
    $r->push_handlers(PerlLogHandler => $helperdetect);

    # push the cleanup handler to save the session:
    DEBUG("Pushing PerlCleanupHandler to save session");
    $r->push_handlers(PerlCleanupHandler => sub {
        my ($r) = @_;
        DEBUG("A2C session cleanup: start handler sub");

        # just return if connection was detected as aborted in Log phase
        # while the connection was still open
        return Apache2::Const::OK if $r->notes->{connection_closed};

        DEBUG("connection not aborted, saving session...");

        # connection finished successfully thru whole cycle, so save session
        my $tied_session = $r->pnotes->{_tied_session};
        Apache2::Controller::X->throw('no tied session in pnotes') 
            if !defined $tied_session;
        DEBUG("ref of pnotes tied_session is '$tied_session'.");

        my $session_copy = $r->pnotes->{session};
        Apache2::Controller::X->throw('no pnotes->{session}')
            if !defined $session_copy;

        DEBUG(sub{"putting copy data back into tied session:\n".Dump($session_copy)});
        %{$tied_session} = %{$session_copy}; 

        DEBUG(sub {
            my %debug_sess = %{$tied_session};
            "real session is now:\n".Dump(\%debug_sess);
        });

        return Apache2::Const::OK;
    });

    DEBUG("returning OK");
    return Apache2::Const::OK;
}

=head2 get_options

The default C<get_options> method uses Apache2::Session::File.

Default settings try to create subdirectories under /tmp/a2c_sessions
and /var/lock/a2c_sessions which are named for the hostname of
the current request, such as the virtual host name.

If you use Windows or want to do something differently, use your
own settings or overload C<get_options()>.

If you use Windows, you're chicken.  Live free!

=cut

sub get_options {
    my ($self) = @_;

    my $r = $self->{r};
    my $hostname = $r->hostname();

    my $opts  = $self->get_directive('A2CSessionOptions') || {
        Directory       => "/tmp/a2c_sessions/$hostname",
        LockDirectory   => "/var/lock/a2c_sessions/$hostname",
    };

    my $ref = ref $opts;
    if (!$ref) {
        $opts =~ s{ \A \s+ }{}mxs;
        $opts =~ s{ \s+ \z }{}mxs;
        $opts = { split m{ \s+ }mxs, $opts };
    }
    elsif ($ref eq 'ARRAY') {
        $opts = { @{$opts} };
    }
    DEBUG("returning session opts:\n".Dump($opts));
    return $opts;
}


=head1 SEE ALSO

L<Apache2::Controller::Session::Cookie>, 

L<Apache::Session>,

L<Apache2::Controller::Dispatch>,

L<Apache2::Controller>,

=head1 AUTHOR

Mark Hedges, C<< <hedges at scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


1;
