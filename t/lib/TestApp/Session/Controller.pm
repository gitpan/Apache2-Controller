package TestApp::Session::Controller;

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use base qw( 
    Apache2::Controller
    Apache2::Controller::Render::Template
);

use Readonly;
use Apache2::Const -compile => qw(HTTP_OK);
use Log::Log4perl qw(:easy);
use YAML::Syck;

sub allowed_methods {qw( set read )}

sub set {
    my ($self) = @_;
    DEBUG('setting session data');
    $self->content_type('text/plain');
    my ($data) = $self->param('data') =~ m{ \A (.*?) \z }mxs;
    die "no data param!\n" if !$data;
    DEBUG("received param data:\n$data|||\n");
    $self->{session}{testdata} = Load($data);
    DEBUG(sub { "session data is now:\n".Dump($self->{session}) });
    $self->print("Set session data.\n");
    return Apache2::Const::HTTP_OK;
}

# test path_args:
sub read {
    my ($self) = @_;
    DEBUG('Printing session data');
    $self->content_type('text/plain');
    $self->print(Dump($self->{session}));
    return Apache2::Const::HTTP_OK;
}


1;
