package App::Deps::Verify::App::VerifyDeps::Command::py3list;

use App::Deps::Verify::App::VerifyDeps -command;

use strict;
use warnings;

use Path::Tiny        qw/ path /;
use App::Deps::Verify ();

sub abstract { "list python3 dependencies from PyPI" }

sub description { return abstract(); }

sub opt_spec
{
    return ( [ "input|i=s\@", "the input files" ], );
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

    foreach my $mod (
        @{ App::Deps::Verify->new->list_python3_modules_in_yamls(
                +{ filenames => [ @{ $opt->{input} }, ] }
            )->{missing_python3_modules}
        }
        )
    {
        print "$mod->{module}\n";
    }

    return;
}

1;

