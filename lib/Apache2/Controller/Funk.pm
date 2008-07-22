=head1 NAME

Apache2::Controller::Funk

=head1 SYNOPSIS

 $bool = controller_allows_method($class, $method); 

 check_allowed_method($class, $method);     # throws NOT_FOUND exception

=head1 DESCRPTION

Useful routines for both Apache2::Controller and Apache2::Controller::Dispatch
objects to run.  Results and whether to 'require' are cached in this package's
namespace across requests, optimizing efficiency per mod_perl2 child, and are
queried futher using 'exists', which is very fast.

=cut

package Apache2::Controller::Funk;

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use base 'Exporter';

use Apache2::Controller::Version;

use Log::Log4perl qw( :easy );
use Readonly;
use YAML::Syck;

use Apache2::Controller::X;
use Apache2::Const -compile => qw( NOT_FOUND );

use UNIVERSAL qw( isa );

our @EXPORT_OK = qw(
    controller_allows_method
    check_allowed_method
    log_bad_request_reason
);

Readonly my $ACCESS_LOG_REASON_LENGTH => 60;


=head1 IMPORTABLE FUNCTIONS

=head2 controller_allows_method

 $bool = controller_allows_method($class, $method); # controller_allows_method()

Ask if method name is in @ALLOWED_METHODS in the given controller package.

Only two 'exists' calls are required for each query after caching the 
first result for this child.

=cut

my %allowed_methods = ( );
sub controller_allows_method {
    my ($class, $method) = @_;

    Apache2::Controller::X->throw("class undefined")  if !defined $class;
    Apache2::Controller::X->throw("method undefined") if !defined $method;
    DEBUG(sub{
        "checking class '$class', method '$method', allowed is:\n"
        .Dump(\%allowed_methods)
    });

    # check that the method is allowed.
    # make sure the selected method is allowed in the controller class

    if (!exists $allowed_methods{$class}) {

        eval "require $class;";
        Apache2::Controller::X->throw("cannot require $class: $EVAL_ERROR")
            if $EVAL_ERROR;

        my $isa_a2c; 
        eval "\$isa_a2c = $class->isa('Apache2::Controller');";
        Apache2::Controller::X->throw("$class is not an Apache2::Controller")
            unless $isa_a2c;

        my @allowed_methods = ( );
        my $stmt = '@allowed_methods = @'.$class.'::ALLOWED_METHODS;';
        DEBUG("stmt: '$stmt'");
        eval $stmt;
        Apache2::Controller::X->throw(
            "$class does not have \@ALLOWED_METHODS: $EVAL_ERROR"
        ) if $EVAL_ERROR;

        DEBUG("allowed_methods: (@allowed_methods)");
        $allowed_methods{$class} = { map {($_=>1)} @allowed_methods };
        DEBUG(sub{Dump(\%allowed_methods)});
    }
    return exists $allowed_methods{$class}{$method};
}

=head2 check_allowed_method

 check_allowed_method($method, $class); # check_allowed_method()

Throw a NOT_FOUND exception if the method is not an allowed method
in the @ALLOWED_METHODS array in the controller package.

=cut

sub check_allowed_method {
    my ($class, $method) = @_;
    Apache2::Controller::X->throw("class undefined")  if !defined $class;
    Apache2::Controller::X->throw("method undefined") if !defined $method;
    DEBUG("checking class '$class', method '$method'");

    if (!controller_allows_method($class, $method)) {
        DEBUG("Method $method not allowed in $class.");
        Apache2::Controller::X->throw(
            message     => "Method $method not allowed from $class.",
            status => Apache2::Const::NOT_FOUND,
        );
    }
    return;
}

=head2 log_bad_request_reason( )

 log_bad_request_reason( $r, $X );

Call $r->log_reason( $msg, $r->uri() ) where $msg is a truncated
version of $X in case $X is too long.

=cut

sub log_bad_request_reason {
    my ($r, $X) = @_;
    Apache2::Controller::X->throw('usage: log_bad_request_reason($r, $X)') 
        if !$r || !ref($r) || !$r->can('log_reason') || !$X;
    
    my $x_text = "$X";
    my $reason = $ACCESS_LOG_REASON_LENGTH < length $x_text
        ? substr($x_text, 0, $ACCESS_LOG_REASON_LENGTH)
        : $x_text;
    $r->log_reason( $reason, $r->uri() );
    return;
}

1;
