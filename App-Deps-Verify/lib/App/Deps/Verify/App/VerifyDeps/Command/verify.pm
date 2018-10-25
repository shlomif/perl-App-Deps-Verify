package App::Deps::Verify::App::VerifyDeps::Command::verify;

use App::Deps::Verify::App::VerifyDeps -command;

use strict;
use warnings;

use Path::Tiny qw/ path /;
use App::Deps::Verify ();

sub abstract { "verify the presence of dependencies" }

sub description { return abstract(); }

sub opt_spec
{
    return (
        [ "output|o=s",  "path to output file" ],
        [ "input|i=s\@", "the input files" ],
    );
}

sub validate_args
{
    my ( $self, $opt, $args ) = @_;

    # no args allowed but options!
    $self->usage_error("No args allowed") if @$args;
}

sub execute
{
    my ( $self, $opt, $args ) = @_;

    App::Deps::Verify->new->verify_deps_in_yamls(
        +{ filenames => [ @{ $opt->{input} }, ] } );

    path( $opt->{output} )->spew_utf8("Success!");
}

1;

