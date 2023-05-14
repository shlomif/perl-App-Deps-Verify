package App::Deps::Verify::App::VerifyDeps::Command::plupdatetask;

use App::Deps::Verify::App::VerifyDeps -command;

use strict;
use warnings;

use Path::Tiny        qw/ path /;
use App::Deps::Verify ();

sub abstract { "update a Task::Weaver perl5 dependencies Task" }

sub description { return abstract(); }

sub opt_spec
{
    return (
        [ "input|i=s\@", "the input files" ],
        [ "mutate=s",    "the .pm file to mutate" ],
    );
}

sub validate_args
{
    my ( $self, $opt, $args ) = @_;

    # no args allowed but options!
    $self->usage_error("No args allowed") if @$args;
}

sub _mutate
{
    my ( $self, $text, $toadd ) = @_;

    my @old = ( map { s/\A=pkg\s+//r } ( $text =~ /(^=pkg [^\n]+)/gms ) );

    my %mods = ( map { $_ => 1 } @old, @$toadd );

    return join '', map { "=pkg $_\n\n" } sort keys %mods;
}

sub execute
{
    my ( $self, $opt, $args ) = @_;

    my @new = (
        grep { /\A[A-Za-z0-9_:]+\z/ }
            @{ App::Deps::Verify->new->list_perl5_modules_in_yamls(
                +{ filenames => [ @{ $opt->{input} }, ] }
            )->{perl5_modules}
            }
    );

    path( $opt->{mutate} )->edit_utf8(
        sub {
            s%^((?:=pkg\s+\S+(?:\s+\S+)?\n+)+)%
            $self->_mutate($1, \@new)
            %ems;
        }
    );

    return;
}

1;
