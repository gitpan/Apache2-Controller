package TestApp::Render::Controller;

use strict;
use warnings FATAL => 'all';
use English '-no_match_vars';

use base qw( 
    Apache2::Controller
    Apache2::Controller::Render::Template
    Apache2::Request
);

use Readonly;
use Apache2::Const -compile => qw(HTTP_OK);
use Log::Log4perl qw(:easy);

sub allowed_methods {qw( default pie process )}

sub default {
    my ($self) = @_;
    DEBUG("This is a test.  default()");
    $self->render();
    return Apache2::Const::HTTP_OK;
}

# test path_args:
sub pie {
    my ($self) = @_;
    $self->render();
    return Apache2::Const::HTTP_OK;
}

# test template process of relative files
sub process {
    my ($self) = @_;
    $self->render();
    return Apache2::Const::HTTP_OK;
}

1;
