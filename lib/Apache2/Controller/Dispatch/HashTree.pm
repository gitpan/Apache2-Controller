package Apache2::Controller::Dispatch::HashTree;

=head1 NAME

Apache2::Controller::Dispatch::HashTree - 
Hash tree dispatch for L<Apache2::Controller::Dispatch>

=head1 SYNOPSIS

 <Location "/subdir">
     SetHandler modperl
     PerlInitHandler MyApp::Dispatch
 </Location>

 # lib/MyApp::Dispatch:

 package MyApp::Dispatch;
 use base qw(
     Apache2::Controller::Dispatch::HashTree
 );

 our %dispatch_map = (
    foo => {
        default     => 'MyApp::C::Foo',
        bar => {
            biz         => 'MyApp::C::Biz',
            baz         => 'MyApp::C::Baz',
        },
    },
 );

 1;
 __END__

This maps uri's to controller modules as follows:

 /subdir/foo                    MyApp::C::Foo->default()

 /subdir/foo/bar                MyApp::C::Foo->bar()

 /subdir/foo/bar/zerm           MyApp::C::Foo->bar(), path_args == ['zerm']

 /subdir/foo/bar/biz            MyApp::C::Biz->default()

 /subdir/foo/biz/baz/noz/wiz    MyApp::C::Baz->noz(), path_args == ['wiz']

In the second example, if C<<MyApp::C::Foo>> did not implement or allow
C<<bar()>> as a controller method, then this would select
C<<MyApp::C::Foo->default()>>.

=head1 DESCRIPTION

Implements find_controller() for Apache2::Controller::Dispatch with
a simple hash-based mapping.  Uses substr to divide the uri and
exists to check cached mappings, so it should be pretty fast.

This dispatches URI's in a case-insensitive fashion.  

=head1 METHODS

=cut

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';
use Carp qw( confess );

use base qw( Apache2::Controller::Dispatch );

use Apache2::Controller::Version;

use Apache2::Controller::X;
use Apache2::Controller::Funk qw( controller_allows_method check_allowed_method );

use Log::Log4perl qw(:easy);
use YAML::Syck;

=head2 find_controller

Find the controller and method for a given URI from the data
set in the dispatch class module.

=cut

sub find_controller {
    my ($self) = @_;
    my $dispatch_map = $self->get_dispatch_map();
    my $r = $self->{r};
    my $location = $r->location();
    my $uri = $r->uri();

    DEBUG(sub{Dump({
        uri             => $uri,
        location        => $location,
    })});

    # efficiently split up the uri into an array of path parts
    my @path;
    my $j = 0;
    my $uri_len = length $uri;
    my $prev_char = q{};
    CHAR:
    for (my $i = 1; $i < $uri_len; $i++) {
        my $char = substr $uri, $i, 1;
        if ($char eq '/') {
            # skip over repeat //'s
            next CHAR if $char eq $prev_char;
            $j++;
        }
        else {
            $path[$j] .= $char;
        }
        $prev_char = $char;
    }
    $uri = substr $uri, 1 if $uri_len;

    # follow these keys through the hash and push remaining path parts
    # to an array for after we're done searching for the method
    my @path_hash_elems;
    my @path_args;
    my $node = $dispatch_map;
    push @path_hash_elems, $node;
    my $path_count = scalar @path;
    my $path_last_idx = $#path;

    my %results = ();

    my @defaults;

    my @trace_path;
    @trace_path = map { 
        ref $node   # wow, i didn't know you could do this...
            ? do { $node = $node->{$_}; $node }
            : undef
    } @path;
    DEBUG(sub{"LAME:\n".Dump(\@trace_path)});
    
    FIND_NODE:
    for (my $i = $#trace_path; $i >= 0; $i--) {

        next FIND_NODE if !exists $trace_path[$i];

        my $node = $trace_path[$i];

        my $part = $path[$i];

        DEBUG(sub { "part = '$part', i = $i, node = ".Dump($node) });

        my $ref  = ref $node;

        my $maybe_method = $path[$i + 1];
        my $maybe_controller = $ref ? $node->{default} : $node;

        next FIND_NODE if !$maybe_controller;  # no default specified, no matches

        DEBUG(sub {
            "ctrl? => '$maybe_controller', method? => ".($maybe_method || '[none]')
        });

        if  (   $maybe_method
            &&  controller_allows_method($maybe_controller => $maybe_method)
            ) {
            # got it!
            $results{controller} = $maybe_controller;
            $results{method}     = $maybe_method;
            @path_args  = @path[ $i + 2 .. $#path ];
            last FIND_NODE;
        }
        else {  # maybe 'default' here?
            if (controller_allows_method($maybe_controller => 'default')) {
                $results{controller} = $maybe_controller;
                $results{method}     = 'default';
                @path_args  = @path[ $i + 1 .. $#path ];
                last FIND_NODE;
            }
            else {
                # not here... go back one
                next FIND_NODE;
            }
        }
    }

    DEBUG(sub{Dump({
        path_args => \@path_args,
        results => \%results,
    })});

    my @result_keys = keys %results;

    # make sure this worked
    Apache2::Controller::X->throw("did not detect $_")
        for grep !exists $results{$_}, @result_keys;

    # save the info in notes
    $r->notes->{$_} = $results{$_} for @result_keys;

    $r->pnotes->{path_args}         = \@path_args;

    # now try finding a matching module in dispatch_map

    #######################################################
    return $results{controller};
}

=head1 SEE ALSO

L<Apache2::Controller::Dispatch>

L<Apache2::Controller::Dispatch::Simple>

L<Apache2::Controller>

=head1 AUTHOR

Mark Hedges, C<hedges +(a t)| scriptdolphin.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Mark Hedges.  CPAN: markle

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut


1;