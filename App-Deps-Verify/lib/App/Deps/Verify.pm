package App::Deps::Verify;

use strict;
use warnings;
use autodie;
use 5.014;

use Moo;

use File::Which qw/ which /;
use YAML::XS    qw/ LoadFile /;
use Path::Tiny  qw/ path /;

sub _load_yamls
{
    my ( $self, $args ) = @_;

    return [ map { LoadFile($_) } @{ $args->{filenames} } ];
}

sub verify_deps_in_yamls
{
    my ( $self, $args ) = @_;

    return $self->find_deps(
        {
            inputs => $self->_load_yamls($args),
        }
    );
}

sub list_perl5_modules_in_yamls
{
    my ( $self, $args ) = @_;

    return $self->list_perl5_modules(
        {
            inputs => $self->_load_yamls($args),
        }
    );
}

sub list_python3_modules_in_yamls
{
    my ( $self, $args ) = @_;

    return $self->list_missing_python3_modules(
        {
            inputs => [
                map { $_->{required}->{py3_modules} }
                    @{ $self->_load_yamls($args) }
            ],
        }
    );
}

sub _find_exes
{
    my ( $self, $args ) = @_;

    my @not_found;
    foreach my $line ( map { @$_ } @{ $args->{inputs} } )
    {
        my $cmd = $line->{exe};
        if (
            not(
                  ( $cmd =~ m{\A/} )
                ? ( -e $cmd )
                : ( defined( scalar( which($cmd) ) ) )
            )
            )
        {
            push @not_found, $line;
        }
    }

    if (@not_found)
    {
        print "The following commands could not be found:\n\n";
        foreach my $cmd ( sort { $a->{exe} cmp $b->{exe} } @not_found )
        {
            print "$cmd->{exe}\t$cmd->{url}\n";
        }
        exit(-1);
    }
    return;
}

sub list_perl5_modules
{
    my ( $self, $args ) = @_;

    my $inputs = $args->{inputs};
    my $map    = sub {
        my ($key) = @_;
        return [ map { $_->{required}->{$key} } @$inputs ];
    };

    my $args_m = sub {
        my ($key) = @_;
        return +{ inputs => $map->($key), };
    };
    my $reqs = +{};
    foreach my $required_modules ( @{ $args_m->('perl5_modules')->{inputs} } )
    {
        foreach my $m ( keys(%$required_modules) )
        {
            $reqs->{$m} = 1;
        }
    }
    return +{ perl5_modules => [ sort { $a cmp $b } keys %$reqs ] };
}

sub _find_perl5_modules
{
    my ( $self, $args ) = @_;

    my @not_found;

    foreach my $required_modules ( @{ $args->{inputs} } )
    {
        foreach my $m ( sort { $a cmp $b } keys(%$required_modules) )
        {
            my $v = $required_modules->{$m};
            local $SIG{__WARN__} = sub { };
            my $verdict = eval( "use $m " . ( $v || '' ) . ' ();' );
            my $Err     = $@;

            if ($Err)
            {
                push @not_found, $m;
            }
        }
    }

    if (@not_found)
    {
        print "The following modules could not be found:\n\n";
        foreach my $module (@not_found)
        {
            print "$module\n";
        }
        exit(-1);
    }
    return;
}

sub list_missing_python3_modules
{
    my ( $self, $args ) = @_;
    my %not_found;
    foreach my $mods ( @{ $args->{inputs} } )
    {
        use Data::Dumper;

        # die Dumper($mods);
        my @required_modules = keys %{$mods};

    REQUIRED:
        foreach my $module (@required_modules)
        {
            if ( $module !~ m#\A[a-zA-Z0-9_\.]+\z# )
            {
                die "invalid python3 module id - $module !";
            }
            if ( exists $not_found{$module} )
            {
                next REQUIRED;
            }
            if ( system( 'python3', '-c', "import $module" ) != 0 )
            {
                $not_found{$module} = 0;
            }
        }
    }
    return { missing_python3_modules =>
            [ map { +{ module => $_, }, } sort keys(%not_found) ] };
}

sub _find_python3_modules
{
    my ( $self, $args ) = @_;
    my @not_found =
        map { $_->{module} }
        @{ $self->list_missing_python3_modules($args)->{missing_python3_modules}
        };
    if (@not_found)
    {
        print "The following python3 modules could not be found:\n\n";
        foreach my $module (@not_found)
        {
            print "$module\n";
        }
        exit(-1);
    }
    return;
}

sub _find_required_files
{
    my ( $self, $args ) = @_;

    my @not_found;

    foreach my $required_files ( @{ $args->{inputs} } )
    {
        foreach my $path (@$required_files)
        {
            my $p = $path->{path};
            if ( $p =~ m#[\\\$]# )
            {
                die "Invalid path $p!";
            }
            if ( !-e ( $p =~ s#\A~/#$ENV{HOME}/#r ) )
            {
                push @not_found, $path;
            }
        }
    }

    if (@not_found)
    {
        print "The following required files could not be found.\n";
        print "Please set them up:\n";
        print "\n";

        foreach my $path (@not_found)
        {
            print "$path->{path}\n$path->{desc}\n";
        }
        exit(-1);
    }
    return;
}

sub find_deps
{
    my ( $self, $args ) = @_;

    my $inputs = $args->{inputs};

    my $map = sub {
        my ($key) = @_;
        return [ map { $_->{required}->{$key} } @$inputs ];
    };

    my $args_m = sub {
        my ($key) = @_;
        return +{ inputs => $map->($key), };
    };

    $self->_find_exes( $args_m->('executables') );
    $self->_find_perl5_modules( $args_m->('perl5_modules') );
    $self->_find_python3_modules( $args_m->('py3_modules') );
    $self->_find_required_files( $args_m->('files') );

    return;
}

sub write_rpm_spec_from_yaml_file
{
    my ( $self, $args ) = @_;

    $self->write_rpm_spec_text_from_yaml_file_to_fh(
        +{
            deps_fn => $args->{deps_fn},
            out_fh  => scalar( path( $args->{out_fn} )->openw_utf8 ),
        }
    );

    return;
}

sub write_rpm_spec_text_from_yaml_file_to_fh
{
    my ( $self, $args, ) = @_;

    my ($yaml_data) = LoadFile( $args->{deps_fn} );
    return $self->write_rpm_spec_text_to_fh(
        {
            data   => $yaml_data,
            out_fh => $args->{out_fh},
        }
    );
}

my %EXES_TRANSLATIONS = (
    cookiecutter => 'python3-cookiecutter',
    convert      => 'imagemagick',
    gm           => 'graphicsmagick',
    node         => 'nodejs',
);

sub write_rpm_spec_text_to_fh
{
    my ( $self, $args, ) = @_;

    my $yaml_data = $args->{data};
    my $yamls     = [$yaml_data];
    if ( !$yaml_data )
    {
        $yamls     = $args->{yamls};
        $yaml_data = $yamls->[0];
    }
    my $ret = '';
    my $o   = $args->{out_fh};

    my $keys = $yaml_data->{required}->{meta_data}->{'keys'};
    $o->print(<<"EOF");
Summary:    $keys->{summary}
Name:       $keys->{package_name}
Version:    0.0.1
Release:    %mkrel 1
License:    MIT
Group:      System
Url:        $keys->{url}
BuildArch:  noarch
EOF
    {
        foreach my $exess ( map { $_->{required}->{executables} } @$yamls )
        {
        EXECUTABLES:
            foreach my $line (@$exess)
            {
                my $cmd = $line->{exe};
                if ( $cmd eq 'sass' or $cmd eq 'minify' )
                {
                    next EXECUTABLES;
                }
                elsif ( exists $EXES_TRANSLATIONS{$cmd} )
                {
                    $cmd = $EXES_TRANSLATIONS{$cmd};
                }
                $o->print("Requires: $cmd\n");
            }
        }
    }
    foreach my $y (@$yamls)
    {
        my $required_modules = $y->{required}->{perl5_modules};

        foreach my $m ( sort { $a cmp $b } keys(%$required_modules) )
        {
            $o->print("Requires: perl($m)\n");
        }
    }
    foreach my $y (@$yamls)
    {
        my @required_modules =
            keys %{ $y->{required}->{py3_modules} };

        foreach my $module (@required_modules)
        {
            if ( $module eq 'bs4' )
            {
                $module = 'beautifulsoup4';
            }
            $o->print("Requires: python3dist($module)\n");
        }
    }

    $o->print(<<"EOF");

%description
$keys->{desc}

%files

%changelog
* Mon Jan 12 2015 shlomif <shlomif\@shlomifish.org> 0.0.1-1.mga5
- Initial package.
EOF

    return;
}

1;

=encoding utf8

=head1 NAME

App::Deps::Verify - app and API to verify the presence of dependencies (Perl 5 modules, python3 modules, executables, etc.)

=head1 SYNOPSIS

    use App::Deps::Verify ();

    App::Deps::Verify->new->verify_deps_in_yamls(
        +{ filenames => [ $opt->{input}, ] } );

    path( $opt->{output} )->spew_utf8("Success!");

=head1 DESCRIPTION

Here are some examples for YAML input files:

=over 4

=item * L<https://github.com/shlomif/shlomi-fish-homepage/blob/master/bin/required-modules.yml>

=item * L<https://github.com/shlomif/perl-begin/blob/master/bin/required-modules.yml>

=item * L<https://github.com/shlomif/fc-solve/blob/master/fc-solve/site/wml/bin/required-modules.yml>

=back

=head1 METHODS

=head2 $obj->verify_deps_in_yamls({filenames => [@FILENAMES]})

Verify the presence of deps in all the YAML files.

=head2 $obj->find_deps({inputs => [\%hash1, \%hash2, ...]})

Verify the presence of deps in all the input hashes.

=head2 $obj->write_rpm_spec_from_yaml_file({deps_fn => $path, out_fn => $path});

=head2 $obj->write_rpm_spec_text_from_yaml_file_to_fh({deps_fn => $path, out_fh => $fh});

=head2 $obj->write_rpm_spec_text_to_fh({data => $yaml_data, out_fh => $fh});

Or:

=head2 $obj->write_rpm_spec_text_to_fh({yamls => [@ARRAY], out_fh => $fh});

=head2 $obj->list_perl5_modules({inputs => [\%hash1, \%hash2, ...]})

List the perl5 modules dependencies.

Added in version 0.2.0.

=head2 $obj->list_perl5_modules_in_yamls({filenames => [@FILENAMES]})

Added in version 0.2.0.

=head2 $obj->list_python3_modules_in_yamls({filenames => [@FILENAMES]})

Added in version 0.12.0.

=head2 $obj->list_missing_python3_modules({inputs => [\%hash1, \%hash2, ...]})

List the python3 modules dependencies.

Added in version 0.12.0

=cut
