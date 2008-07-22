package Apache2::Controller::Const;

=head1 NAME

Apache2::Controller::Const - constants for Apache2::Controller

=head1 VERSION

Version 0.101.111 - BETA TESTING (ALPHA?)

=cut

our $VERSION = version->new('0.101.111');

=head1 SYNOPSIS

 use Apache2::Controller::Const 
    '@RANDCHARS',
    qw( $NOT_GOOD_CHARS $ACCESS_LOG_REASON_LENGTH );

=head1 DESCRIPTION

Various common Readonly constants for use by Apache2::Controller modules.

=head1 CONSTANTS

=cut

use strict;
use warnings FATAL => 'all';
use Readonly;

use base 'Exporter';

our @EXPORT_OK = qw(
    @RANDCHARS
    $NOT_GOOD_CHARS
);

=head2 @RANDCHARS

An array of the alphabet from which to pick random characters.

=cut

Readonly our @RANDCHARS => 'A'..'Z', 'a'..'z', 0..9;

=head2 $NOT_GOOD_CHARS

A strict qr{} pattern of characters that are not good for basic user input.
Maybe get rid of this one...

=cut

Readonly our $NOT_GOOD_CHARS => qr{ [^\w\#\@\.\-:/, ] }mxs;

=head1 SEE ALSO

Apache2::Controller

=cut

1;
