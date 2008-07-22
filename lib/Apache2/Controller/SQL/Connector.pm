package Apache2::Controller::SQL::Connector;

=head1 NAME

Apache2::Controller::SQL::Connector - connects L<DBI|DBI> to C<<$r->pnotes->{dbh}>>.

=head1 SYNOPSIS

=head2 CONFIG ALTERNATIVE 1: APACHE CONF

 # virtualhost.conf:
 
 PerlLoadModule Apache::DBI
 PerlLoadModule Apache2::Controller::Directives
 <Location '/'>
     A2C_DBI_DSN        DBI:mysql:database=foobar;host=localhost
     A2C_DBI_User       heebee
     A2C_DBI_Password   jeebee
     A2C_DBI_Options    RaiseError  1
     A2C_DBI_Options    AutoCommit  0

     SetHandler                 modperl
     PerlInitHandler            MyApp::Dispatch
     PerlHeaderParserHandler    Apache2::Controller::SQL::Connector
 </Location>

=head2 CONFIG ALTERNATIVE 2: SUBCLASS 

If you need to hide details from the server configuration tree,
for example to hide password from access by untrusted cgi scripts,
subclass this module and implement your own C<<dbi_connect_args()>>
subroutine, which returns argument list for C<<DBI->connect()>>.

 PerlLoadModule Apache::DBI
 <Location '/'>
     SetHandler                 modperl
     PerlInitHandler            MyApp::Dispatch
     PerlHeaderParserHandler    MyApp::SQLConnect
 </Location>

 package MyApp::SQLConnect;
 use base qw( Apache2::Controller::SQL::Connector );
 sub dbi_connect_args {
     my ($self) = @_;
     return (
         'DBI:mysql:database=foobar;host=localhost',
         'heebee', 'jeebee',
         { RaiseError => 1, AutoCommit => 0 }
     );
 }
 1;

=cut

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use base qw( Apache2::Controller::NonResponseBase );

use Apache2::Controller::Version;

use Log::Log4perl qw(:easy);
use YAML::Syck;

use Apache2::Controller::X;

=head1 METHODS

=head2 process

Gets DBI connect arguments by calling C<< $self->dbi_connect_args() >>,
then connects C<< $dbh >> and stashes it in C<< $r->pnotes->{dbh} >>.

=cut

sub process {
    my ($self) = @_;
    my @args = $self->dbi_connect_args();
    eval {
        my $dbh = DBI->connect(@args);
        $self->{r}->pnotes->{dbh} = $dbh;
    };
    Apache2::Controller::X->throw($EVAL_ERROR) if $EVAL_ERROR;
    return;
}

=head2 dbi_connect_args

Default interprets directives.  L<Apache2::Controller::Directives>.
You can override this in a subclass to provide your own connect args.

=cut

sub dbi_connect_args {
    my ($self) = @_;
    my $directives = $self->get_directives;
    my @names = qw( DSN User Password Options );
    my %opts = map {($_ => $directives->{"A2C_DBI_$_"})} @names;
    return @opts{@names};
}

=head1 SEE ALSO

L<Apache2::Controller::Directives>

L<Apache2::Controller::SQL::MySQL>

L<Apache2::Controller>

L<Apache::DBI>

=head1 AUTHOR

Mark Hedges, C<hedges +(a t)- scriptdolphin.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Mark Hedges.  CPAN: markle

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;

