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

=head1 STASH FUNCTIONS

Several subroutine references are automatically included
in the stash for ease of use.

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

=head2 escape_html

Escape '<' and '>' characters using L<HTML::Entities>.

=cut

sub escape_html {
    my @strings = @_; # clone, don't modify
    return map encode_entities($_, '<>'), @strings;
}

=head2 uri_escape

See L<URI::Escape>.

=head2 Dump

See L<YAML::Syck>.

=cut

sub _assign_tt_functions {
    my ($self) = @_;
    $self->{stash}{escape_html} = \&escape_html;
    $self->{stash}{uri_escape}  = \&uri_escape;
    $self->{stash}{Dump}        = \&Dump;
    return;
}

sub _assign_tt_stash_data {
    my ($self) = @_;
    $self->{stash}{path_args}   = $self->{path_args};
    $self->{stash}{method}      = $self->{method};
    $self->{stash}{controller}  = $self->{class};
    return;
}

=head1 METHODS

=head2 render

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

    my $tt = $self->get_tt_obj();
    my $template = $self->detect_template();
    DEBUG("processing template = '$template'");

  # DEBUG(sub { Dump($self->{stash}) });

    $self->_assign_tt_functions();
    $self->_assign_tt_stash_data();

    # assimilate output to a scalar 
    my $output;
    $tt->process($template, $self->{stash}, \$output) 
        || Apache2::Controller::X->throw($tt->error());

    $self->print($output);

    return;
}

=head2 render_fast

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

    my $template = $self->detect_template();
    DEBUG("processing template = '$template'");

  # DEBUG(sub { Dump($self->{stash}) });

    $self->_assign_tt_functions();

    my $tt = $self->get_tt_obj();
    # pass Apache2::Request object to print directly.
    $tt->process($template, $self->{stash}, $self->{r}) 
        || Apache2::Controller::X->throw($tt->error());

    return;
}

=head2 error

If your template directory contains a subdirectory named 'error', 
then when the controller throws an exception, the exception object will
be passed to a selected error template as 'X' in the stash.  It also
sets http_status (number) and status_line 
(from HTTP::Status::status_message() or from the values 
set in the L<Apache2::Controller::X> exception).

If you have a template $template_dir/error/$status.html, 
where $status is the numeric http status code,
then it will use that template.

For example:

 203 HTTP_NON_AUTHORITATIVE     => error/203.html
 400 HTTP_BAD_REQUEST           => error/400.html
 404 NOT_FOUND                  => error/404.html
 500 HTTP_INTERNAL_SERVER_ERROR => error/500.html

For example, C<$template_dir/error/400.html> or 
C<$template_dir/error/403.html>.

Otherwise it will look for $template_dir/error/default.html and 
try to use that, otherwise it will give up.

error() remembers across requests whether you do or don't have 
error templates for certain messages in the appropriate template directory,
so it will be faster the second time around if you use error/default.html.

For a reference list of http_status and messages, see Apache2::Controller.

Since render_fast() is incompatible if a template rendering error 
occurs, render_fast() turns off the use of error() and relies on 
standard Apache2 error messages (or the custom message set in 
the exception object) and relies on the browser to display them.

=cut

my %error_templates = ( );

sub error {
    my ($self, $X) = @_;

    my ($http_status, $status_line);

    DEBUG("original error: '$X'");

    if (ref($X) && $X->isa('Apache2::Controller::X')) {
        $http_status = $X->http_status;
        $status_line = $X->status_line;
        DEBUG("got status from \$X: ".($http_status || '[none]'));
    }
    $http_status ||= Apache2::Const::SERVER_ERROR;
    $status_line ||= status_message($http_status);

    my $status_file = $http_status;
    DEBUG("status msg for $status_file: '$status_line'");

    $self->{stash}{X} = $X;
    $self->{stash}{status_line} = $status_line;
    $self->{stash}{http_status} = $http_status;

    my $template_dir = $self->get_directive('A2CRenderTemplateDir')
        || Apache2::Controller::X->throw('A2CRenderTemplateDir not defined.');
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
        # does the error directory even exist?

        # first try the appropriately named file:
        my %try_errors = ( );
        $self->{template} = "errors/$status_file.html";
        eval { $self->render() };

        # if got an error using that file name, try the default error file:
        if ($EVAL_ERROR) {
            $try_errors{$self->{template}} = "$EVAL_ERROR";
            $self->{template} = "errors/default.html";
            eval { $self->render() };

            # and if error template doesn't work, throw back original error
            if ($EVAL_ERROR) {
                $try_errors{$self->{template}} = "$EVAL_ERROR";
                $error_templates{$template_dir}{$status_file} = undef;
                if ($X->isa('Apache2::Controller::X')) {
                    $X->rethrow();
                }
                else {
                    my $dump = { tries => \%try_errors, reftype => ref $X };
                    Apache2::Controller::X->throw(
                        message     => "GOMBOR $X",
                        http_status => $http_status,
                        status_line => $status_line,
                        'dump'      => $dump,
                    );
                }
            }
        }

        # after finding the right template for code, remember it for next time
        $error_templates{$template_dir}{$status_file} = $self->{template};
    }
    return;
}

=head2 detect_template

This is called internally by the render methods, but you can use
it to figure out the default template from where you are.

To override the auto-select template, just set $self->{template}
before you call C<<render()>>.

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

sub detect_template {
    my ($self) = @_;

    if (exists $self->{template}) {
        DEBUG("have a template already, returning $self->{template}");
        return $self->{template};
    }

    (my $rel_uri = $self->notes->{relative_uri}) =~ s{ \A / }{}mxs;
    Apache2::Controller::X->throw('notes->{relative_uri} not set')
        if !defined $rel_uri;

    my $file = "$self->{method}.html";

    my $template 
        = $rel_uri
        ? File::Spec->catfile( $rel_uri, $file )
        : $file;

    Apache2::Controller::X->throw("bad template path $_")
        if $template =~ m{ \.\. / }mxs;

    DEBUG("Detected self->{template} to be '$template'");

    $self->{template} = $template;
    return $template;
}

=head2 detect_template_include_dir

Like C<<detect_template()>>, this detects the appropriate include
directory for the template toolkit object, sets it as 
C<<$self->{template_include_dir}>> and returns it.

=cut

sub detect_template_include_dir {
    my ($self) = @_;

    return $self->{template_include_dir} if $self->{template_include_dir};

    my $template_dir = $self->get_directive('A2CRenderTemplateDir')
        || Apache2::Controller::X->throw("A2CRenderTemplateDir not defined");

    (my $loc = $self->location()) =~ s{ \A / }{}mxs;
    DEBUG("so far have '$template_dir' / '$loc'");
    my $uri = $self->uri();

    DEBUG(sub{Dump({
        loc     => $loc,
        uri     => $uri,
        template_dir => $template_dir,
    })});

    my $dir = $self->{template_include_dir} = File::Spec->catfile(
        $template_dir,
        $loc,
    );

    return $dir;
}

=head2 get_tt_obj

Get the L<Template> object set up with the appropriate include directory
from C<<detect_template_include_dir()>>.

=cut

my %tts = ();
sub get_tt_obj {
    my ($self) = @_;
    my $include_dir = $self->detect_template_include_dir();

    return $tts{$include_dir} if exists $tts{$include_dir};

    DEBUG("using include_dir '$include_dir' to set up a new TT object");

    my $tt = Template->new({
        INCLUDE_PATH    => $include_dir,
        INTERPOLATE     => 1,
        ABSOLUTE        => 0,
        RELATIVE        => 1,
    # DEBUG           => 'all',
    }) || die $Template::ERROR;

    $tts{$include_dir} = $tt;

    return $tt;
}

=head1 SEE ALSO

L<Apache2::Controller>

L<Apache2::Controller::Render::Template>

L<Apache2::Controller::X>

=head1 AUTHOR

Mark Hedges, C<< <hedges at--! scriptdolphin.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Mark Hedges, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


1;
