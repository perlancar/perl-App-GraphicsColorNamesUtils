package App::GraphicsColorNamesUtils;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict 'subs', 'vars';
use warnings;

our %SPEC;

sub _get_scheme_codes {
    my ($scheme) = @_;
    my $mod = "Graphics::ColorNames::$scheme";
    (my $modpm = "$mod.pm") =~ s!::!/!g;
    require $modpm;
    my $res = &{"$mod\::NamesRgbTable"}();
    if (ref $res eq 'HASH') {
        for (keys %$res) {
            $res->{$_} = sprintf("%06x", $res->{$_});
        }
        return $res;
    } else {
        return {};
    }
}

sub _get_all_schemes_codes {
    require Module::List::Tiny;
    my $mods = Module::List::Tiny::list_modules(
        "Graphics::ColorNames::", {list_modules=>1});
    my %all_codes;
    for my $mod (sort keys %$mods) {
        (my $scheme = $mod) =~ s/^Graphics::ColorNames:://;
        my $codes = _get_scheme_codes($scheme);
        for (keys %$codes) { $all_codes{$_} //= $codes->{$_} }
    }
    \%all_codes;
}

$SPEC{colorcode2name} = {
    v => 1.1,
    summary => 'Convert RGB color code to name',
    args => {
        code => {
            schema => 'color::rgb24*', # XXX disable coercion from color name
            req => 1,
            pos => 0,
        },
        approx => {
            summary => 'When a name with exact code is not found, '.
                'find the several closest ones',
            schema => 'bool*',
        },
    },
};
sub colorcode2name {
    require Graphics::ColorNames;

    my %args = @_;
    my $code = lc $args{code};

    my $all_codes = _get_all_schemes_codes();

    my %names;
    for my $name (sort keys %$all_codes) {
        my $code = $all_codes->{$name};
        $names{$code} //= [];
        push @{ $names{$code} }, $name
            unless grep { $_ eq $name } @{ $names{$code} };
    }

    if (defined $names{$code}) {
        return [200, "OK", join(", ", @{ $names{$code} })];
    } elsif ($args{approx}) {
        require Color::RGB::Util;

        my @colors_and_diffs =
            sort {
                $a->[2] <=> $b->[2]
            }
            map {
                # name, code, distance to wanted
                [$_, $all_codes->{$_}, Color::RGB::Util::rgb_diff($code, $all_codes->{$_}, 'approx1')]
            } sort keys %$all_codes;
        my @closest = splice @colors_and_diffs, 0, 5;
        return [200, "OK (approx)", [map {+{name=>$_->[0], code=>$_->[1]}} @closest], {
            'table.fields' => [qw/name code/]}];
    } else {
        return [404, "Color code '$code' does not yet have a name"];
    }
}

$SPEC{list_color_schemes} = {
    v => 1.1,
    summary => 'List all installed Graphics::ColorNames schemes',
};
sub list_color_schemes {
    require Graphics::ColorNames;

    my %args = @_;
    [200, "OK", [Graphics::ColorNames::all_schemes()]];
}

$SPEC{colorname2code} = {
    v => 1.1,
    summary => 'Convert color name to code',
    args => {
        name => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
};
sub colorname2code {
    require Graphics::ColorNames;

    my %args = @_;
    my $name = $args{name};

    my $all_codes = _get_all_schemes_codes();
    if (defined $all_codes->{$name}) {
        return [200, "OK", $all_codes->{$name}];
    } else {
        return [404, "Unknown color name '$name'"];
    }
}

$SPEC{list_color_names} = {
    v => 1.1,
    summary => 'List all color names from a Graphics::ColorNames scheme',
    args => {
        scheme => {
            schema => 'perl::modname*',
            req => 1,
            pos => 0,
        },
        detail => {
            schema => 'true*',
            cmdline_aliases => {l=>{}},
        },
    },
};
sub list_color_names {
    require Graphics::ColorNames;

    my %args = @_;

    my $codes = _get_scheme_codes($args{scheme});

    my @rows;
    my $resmeta = {};
    for (sort keys %$codes) {
        push @rows, {name=>$_, rgb=>$codes->{$_}};
    }

    if ($args{detail}) {
        $resmeta->{'table.fields'} = [qw/name rgb/];
    } else {
        @rows = map {$_->{name}} @rows;
    }

    [200, "OK", \@rows, $resmeta];
}

$SPEC{show_color_swatch} = {
    v => 1.1,
    summary => 'List all color names from a Graphics::ColorNames scheme as a color swatch',
    args => {
        scheme => {
            schema => 'perl::modname*',
            req => 1,
            pos => 0,
        },
        width => {
            schema => 'posint*',
            default => 80,
            cmdline_aliases => {w=>{}},
        },
    },
};
sub show_color_swatch {
    require Color::ANSI::Util;
    require Color::RGB::Util;
    require String::Pad;

    my %args = @_;
    my $width = $args{width} // 80;

    my $res = list_color_names(scheme => $args{scheme}, detail=>1);
    return $res unless $res->[0] == 200;

    my $reset = Color::ANSI::Util::ansi_reset();
    for my $row (@{ $res->[2] }) {
        my $empty_bar = " " x $width;
        my $text_bar  = String::Pad::pad("$row->{name} ($row->{rgb})", $width, "center", " ", 1);
        my $bar = join(
            "",
            Color::ANSI::Util::ansibg($row->{rgb}), $empty_bar, $reset, "\n",
            Color::ANSI::Util::ansibg($row->{rgb}), Color::ANSI::Util::ansifg(Color::RGB::Util::rgb_is_dark($row->{rgb}) ? "ffffff" : "000000"), $text_bar, $reset, "\n",
            Color::ANSI::Util::ansibg($row->{rgb}), $empty_bar, $reset, "\n",
            $empty_bar, "\n",
        );
        print $bar;
    }
    [200];
}

1;
#ABSTRACT: Utilities related to Graphics::ColorNames

=head1 DESCRIPTION

This distributions provides the following command-line utilities:

# INSERT_EXECS_LIST


=head1 SEE ALSO

=cut
