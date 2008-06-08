package Apache2::Controller::Render::Template;

=head1 NAME

Apache2::Controller::Render::Template - A2C render() with Template Toolkit

=head1 SYNOPSIS

 # apache2 config file

 PerlModule Apache2::Controller::Directives

 # location of templates - must be defined
 A2CRenderTemplateDir           /var/myapp/templates

 # looks for templates in /var/myapp/templates/foo/
 <Location /foo>
    SetHandler modperl
    PerlOptions +SetupEnv
    PerlInitHandler MyApp::Dispatch::Foo
 </Location>

 # see L<Apache2::Controller::Dispatch> for A2C Dispatch inheritance.

 package MyApp::C::Foo;  # let's assume this controller was dispatched

 use strict;
 use warnings;

 use base qw(
    Apache2::Controller
    Apache2::Controller::Render::Template
    MyApp::Model::Methods
    MyApp::Security
 );

 use Apache2::Const -complie => qw( OK );

 my @ALLOWED_METHODS = qw( default );

 # suppose MyApp::Model::Methods connects dbh in startup sequence
 # and suppose MyApp::Security implements my_detaint_path_args()
 # to call a branch function for 'name' that detaints [ last, first ]

 sub default {
    my ($self) = @_;
    my @path_args = $self->my_detaint_path_args('name'); # from $self->{path_args}

    $self->{stash}{creditcards} = $self->{dbh}->fetchall_arrayref(
        q{  SELECT ccnum, exp, addr1, zip, cac 
            FROM customer_credit_cards 
            WHERE lname = ? AND fname = ?
        }, undef, @path_args
    );

    # request was like http://myserver.xyz/foo/Larry/Wall

    $self->render();    # renders /var/myapp/templates/foo/default.html
    return Apache2::Const::OK;

 }

 __END__
 [%# /var/myapp/templates/foo/default.html %]
 <p>Here is the credit card info you requested for 
 everyone named [% path_args.reverse.join(' ') %]:</p>
 <ul>
 [% FOREACH card = creditcards %]
    [% FOREACH field = ['ccnum','exp','addr1','zip','cac'] %]
    <li><strong>[% field %]:</strong> [% card.$field %]</li>
    [% END %]
 [% END %]
 </ul>
 [%# end template toolkit file %]


=head1 DESCRIPTION

This module provides a nice rendering mechanism for Apache2::Controller.

=head1 METHODS


=cut

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use Apache2::Const -compile => qw( SERVER_ERROR OK );
use Apache2::Controller::X;

use File::Spec;
use Template;
use YAML::Syck;
use URI::Escape;
use HTML::Entities;
use HTTP::Status qw( status_message );
use Log::Log4perl qw( :easy );

my $tt = Template->new({
    INTERPOLATE     => 1,
    ABSOLUTE        => 1,
    RELATIVE        => 0,
  # DEBUG           => 'all',
}) || die $Template::ERROR;

sub escape_html {
    my @strings = @_; # clone, don't modify
    return map encode_entities($_, '<>'), @strings;
}

sub assign_tt_functions {
    my ($self) = @_;
    $self->{stash}{escape_html} = \&escape_html;
    $self->{stash}{uri_escape}  = \&uri_escape;
    $self->{stash}{Dump}        = \&Dump;
    return;
}

sub assign_tt_stash_data {
    my ($self) = @_;
    $self->{stash}{path_args}   = $self->{path_args};
    $self->{stash}{method}      = $self->{method};
    $self->{stash}{controller}  = $self->{class};
    return;
}

my $incpath;
sub incpath_generator {
    Apache2::Controller::X->throw("no incpath set for incpath_generator()")
        if !defined $incpath;
    return ref $incpath ? $incpath : [ $incpath ];
}

=head2 render()

render() accumulates template output into a variable
before printing, so it may use a lot of memory
if you expect a large data set.

It does this so it can intercept Template errors
and kick up an exception to be printed using your
error templates.  See error().

=cut

sub render {
    my ($self) = @_;

    DEBUG("beginning render()");

    my $template = $self->template();
    DEBUG("processing template = '$template'");

  # DEBUG(sub { Dump($self->{stash}) });

    $self->assign_tt_functions();
    $self->assign_tt_stash_data();

    # assimilate output to a scalar 
    my $output;
    $tt->process($template, $self->{stash}, \$output) 
        || Apache2::Controller::X->throw($tt->error());

    $self->print($output);

    return;
}

=head2 render_fast()

So if you are planning to get a large
data set, you probably want to use $self->render_fast()
and put the database query handle somewhere in $self->{stash}
and call fetchrow() in a Template block. 

With render_fast(), Template->process() outputs directly to 
Apache2::Request->print().  So if a Template error is encountered,
some output may have already been sent to the browser, resulting
in a completely screwed up screen when the exception is kicked
back up to the server.  

Tip: if you plan to use render_fast(), write a test suite that
tests the output of your page.

Of course you could bypass rendering altogether and just use
$self->print().  (Remember that $self is subclassed Apache2::Request.)
Or maybe you should implement an ajax style control in the template
and put a limit frame on the query above, or use a paging lib, etc. ...

=cut

sub render_fast {
    my ($self) = @_;

    $self->notes->{use_standard_errors} = 1;

    my $template = $self->template();
    DEBUG("processing template = '$template'");

  # DEBUG(sub { Dump($self->{stash}) });

    $self->assign_tt_functions();

    # pass Apache2::Request object to print directly.
    $tt->process($template, $self->{stash}, $self->{r}) 
        || Apache2::Controller::X->throw($tt->error());

    return;
}

=head2 error()

If your template directory contains a subdirectory named 'error', 
then when the controller throws an exception, the exception object will
be passed to a selected error template as 'X' in the stash.  It also
sets http_status (number) and status_message 
(from HTTP::Status::status_message()).

If you have a template $template_dir/error/$status_message.html, 
where $status_message is the result of 
C<HTTP::Status::status_message( $http_status_code )>
with spaces and -'s translated to _'s, then it will use that template.

For example:

 203 HTTP_NON_AUTHORITATIVE     => error/Non_Authoritative_Information.html
 400 HTTP_BAD_REQUEST           => error/Bad_Request.html
 404 NOT_FOUND                  => error/Not_Found.html
 500 HTTP_INTERNAL_SERVER_ERROR => error/Internal_Server_Error.html

For example, C<$template_dir/error/Bad_Request.html> or 
C<$template_dir/error/Forbidden.html>.

Otherwise it will look for $template_dir/error/default.html and 
try to use that, otherwise it will give up.

error() remembers across requests whether you do or don't have 
error templates for certain messages in the appropriate template directory,
so it will be faster the second time around if you use error/default.html.

For a reference list of http_status and messages, see Apache2::Controller.

Since render_fast() is incompatible if a template rendering error 
occurs, render_fast() turns off the use of error() and relies on 
standard Apache2 error messages.

=cut

my %error_templates = ( );

sub error {
    my ($self, $X) = @_;

    my $http_status;

    DEBUG("original error: '$X'");

    if (ref($X) && $X->isa('Apache2::Controller::X')) {
        $http_status = $X->http_status;
    }
    else {
        $http_status = $self->{r}->status();
    }
    $http_status ||= Apache2::Const::SERVER_ERROR;

    my $status_message = status_message($http_status);
    (my $status_file = $status_message) =~ s{ [\s\-] }{_}mxsg;
    DEBUG("status msg for file name: '$status_file'");

    $self->{stash}{X} = $X;
    $self->{stash}{status_message} = $status_message;
    $self->{stash}{http_status}    = $http_status;

    my $template_dir = $self->get_directive('A2CRenderTemplateDir');
    if (exists $error_templates{$template_dir}{$status_file}) {

        my $template = $error_templates{$template_dir}{$status_file};
        
        # if exists but undefined, it means it failed totally.
        # forget about using an error template and just rethrow the error
        if (!defined $template) {
            if (ref($X) && $X->isa('Apache2::Controller::X')) {
                $X->rethrow();
            }
            else {
                Apache2::Controller::X->throw(
                    "Cannot process any template for unknown-type error: $X"
                );
            }
        }

        $self->{template} = $template;
        $self->render();
    }
    else {
        # first try the appropriately named file:
        $self->{template} = "errors/$status_file.html";
        eval { $self->render() };
        my %try_errors = ( );

        # if got an error using that file name, try the default error file:
        if ($try_errors{$self->{template}} = "$EVAL_ERROR") {
            $self->{template} = "errors/default.html";
            eval { $self->render() };

            # and if error template doesn't work, throw back merged errors
            if ($try_errors{$self->{template}} = "$EVAL_ERROR") {
                $error_templates{$template_dir}{$status_file} = undef;
                if ($X->isa('Exception::Class::Base')) {
                    if ($X->isa('Apache2::Controller::X')) {
                        my $dump = $X->dump();
                        $dump = $dump
                            ? { initial_error_dump => $dump, %try_errors }
                            : { %try_errors };
                        my $trace = $X->trace();
                        $dump->{initial_error_trace} = "$trace";
                        $X->{dump} = $dump;
                    }
                    $X->rethrow();
                }
                else {
                    my $dump = { initial_error => "$X", %try_errors };
                    $dump->{exception_reftype} = ref $X;
                    Apache2::Controller::X->throw(
                        message => "Cannot process any error template "
                                .  "for $http_status $status_file.",
                        dump    => $dump,
                    );
                }
            }
        }
        $error_templates{$template_dir}{$status_file} = $self->{template};
    }
    return;
}

=head2 template()

This is called internally by the render methods, but you can use
it to figure out the default template from where you are.

To override the auto-select template, just set $self->{template}
before you render.

It looks for templates in a computed directory.  The directory where it
looks will always be the directory set with the A2CRenderTemplateDir 
directive in the config file, appended with the current request location,
i.e. the directory of the Location directive in the config file, 
appended with relative_uri, appended with method name and '.html'.

 A2CRenderTemplateDir + location + relative_uri + method.html

For example, the sequence in SYNOPSIS above renders the file 
C</var/myapp/templates/foo/default.html> .

Suppose the dispatch class above dispatches sub-path uris starting
with 'bar/biz' to another controller.  That controller would look for
templates in the directory /var/myapp/templates/foo/bar/biz/methodname.html.

Example:

 Request: http://myserver.xyz/foo/bar/biz/baz/boz/noz

 location = /foo

 relative_uri = bar/biz

 controller MyApp::C::Foo::Bar::Biz  # mapped in your A2C Dispatch

 found method = baz

 path_args = [ boz, noz ]

 template = /var/myapp/templates + /foo + /bar/biz + /baz.html

 /var/myapp/templates/foo/bar/biz/baz.html

$self->{relative_uri} is the uri relative to the location,
so in other words:  

  location + relative_uri == full uri - path args

See Apache2::Controller::Dispatch::Simple.

=cut

sub template {
    my ($self) = @_;

    if ($self->{template}) {
        DEBUG("have a template already, returning $self->{template}");
        return $self->{template};
    }

    my $template_dir = $self->get_directive('A2CRenderTemplateDir')
        || Apache2::Controller::X->throw("A2CRenderTemplateDir not defined");

    my $loc = $self->location();
    DEBUG("so far have '$template_dir/$loc'");
    my $uri = $self->uri();

    DEBUG(sub{Dump({
        loc     => $loc,
        uri     => $uri,
        template_dir => $template_dir,
    })});

    my $rel_uri = $self->notes->{relative_uri};
    Apache2::Controller::X->throw('notes->{relative_uri} not set')
        if !defined $rel_uri;

    my $template = File::Spec->catfile(
        $template_dir,
        $loc,
        $rel_uri,
        $self->{method}.'.html',
    );

    Apache2::Controller::X->throw("bad template path $template")
        if $template =~ m{ \.\. / }mxs;

    DEBUG("Detected self->{template} to be '$template'");

    $self->{template} = $template;

    return $template;
}

1;
