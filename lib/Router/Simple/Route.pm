package Router::Simple::Route;
use 5.008000;
use strict;
use warnings;
use parent 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw/name dest on_match method host pattern/);

sub new {
    my $class = shift;

    # connect([$name, ]$pattern[, \%dest[, \%opt]])
    if (@_ == 1 || ref $_[1] eq 'HASH') {
        unshift(@_, undef);
    }

    my ($name, $pattern, $dest, $opt) = @_;
    Carp::croak("missing pattern") unless $pattern;
    $opt ||= {};
    my $row = +{
        name     => $name,
        dest     => $dest,
        on_match => $opt->{on_match},
    };
    if (my $method = $opt->{method}) {
        $row->{method} = [ ref $method ? @{$method} : $method ];
        $row->{method_rh} = +{ map { uc $_ => 1 } @{$row->{method}} };
    }
    if (my $host = $opt->{host}) {
        $row->{host} = $host;
        $row->{host_re} = ref $host ? $host : qr{\A$host\z}imsx;
    }
    $row->{pattern} = $pattern;
    if (ref $pattern eq 'Regexp') {
        $row->{pattern_re} = $pattern;
        $row->{capture} = [ ref $opt->{capture} ? @{$opt->{capture}} : () ];
    }
    elsif (! ref $pattern && defined $pattern && $pattern ne q{}) {
        # compile pattern
        my @capture;
        $pattern =~ s{
            (?: ([^\{:*]+)              # normal string
            |   (\*)                    # /entry/*/*
            |   \: ([a-zA-Z0-9_]+)      # /entry/:id
            |   \{ ([a-zA-Z0-9_]+)      # /entry/{id}, /entry/{id:[0-9]{4,}}
                (?: \: ( [^\{\}]+ (?:\{[0-9,]+\} [^\{\}]*)* ) )?
                \}
            )
        }{
            if ($1) {
                quotemeta $1;
            }
            elsif ($2) {
                push @capture, '__splat__';
                q{(.+)};
            }
            else {
                push @capture, defined $3 ? $3 : $4;
                '(' . (defined $5 ? $5 : '[^/]+') . ')';
            }
        }gemsx;
        $row->{pattern_re} = qr{\A$pattern\z}msx;
        $row->{capture} = \@capture;
    }
    else {
        Carp::croak 'invalid pattern';
    }

    return bless $row, $class;
}

sub match {
    my ($self, $env) = @_;
    my $host = $env->{HTTP_HOST} || q{};
    my $method = $env->{REQUEST_METHOD} || q{};
    my $path = $env->{PATH_INFO} || q{};

    return if $self->{host_re} && $host !~ $self->{host_re};
    return if $self->{method_rh} && ! exists $self->{method_rh}{uc $method};

    if ($path =~ $self->{pattern_re}) {
        ## no critic qw(ProhibitPunctuationVars)
        my @match = map { substr $path, $-[$_], $+[$_] - $-[$_] } 1 .. $#-;
        my $dest = +{ %{$self->{dest} || {}} };
        for my $k (@{$self->{capture}}) {
            if ($k eq '__splat__' || $k eq 'splat') {
                push @{$dest->{splat}}, shift @match;
            }
            else {
                $dest->{$k} = shift @match;
            }
        }
        if (@match) {
            push @{$dest->{splat}}, @match;
        }
        if ($self->{on_match}) {
            my $ret = $self->{on_match}->($env, $dest);
            return undef unless $ret;
        }
        return $dest;
    }
    return;
}

1;
__END__

=head1 NAME

Router::Simple::Route - route object

=head1 DESCRIPTION

This class represents route.

=head1 ATTRIBUTES

This class provides following attributes.

=over 4

=item name

=item dest

=item on_match

=item method

=item host

=item pattern

=back

=head1 SEE ALSO

L<Router::Simple>

