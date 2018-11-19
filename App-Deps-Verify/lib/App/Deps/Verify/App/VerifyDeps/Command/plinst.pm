package App::Deps::Verify::App::VerifyDeps::Command::plinst;

use App::Deps::Verify::App::VerifyDeps -command;

use strict;
use warnings;

use Path::Tiny qw/ path /;
use App::Deps::Verify ();

sub abstract { "install perl5 dependencies from CPAN" }

sub description { return abstract(); }

sub opt_spec
{
    return (
        [ "input|i=s\@", "the input files" ],
        [ "notest",      "speed up installation by skipping the tests" ],
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

    exit(
        system(
            "cpanm",
            ( $opt->{notest} ? ('--notest') : () ),
            "--",
            grep { /\A[A-Za-z0-9_:]+\z/ }
                @{ App::Deps::Verify->new->list_perl5_modules_in_yamls(
                    +{ filenames => [ @{ $opt->{input} }, ] }
                )->{perl5_modules}
                }
        )
    );

    return;
}

1;

