package Log::Lager::Tap::Stderr;
our @ISA = qw< Log::Lager::Tap >;

use strict;
use warnings;
use Carp qw( croak );
$Carp::Internal{__PACKAGE__}++;


use constant {
    HANDLE      => 0,
};

sub new {
    my ($class, %opt) = @_;

    my $self = bless [], $class;
    my @bad = sort keys %opt;
    croak "Invalid options for new Log::Lager::Output::Stderr - @bad"
        if @bad;

    return $self;
}

sub dump_config {
    my ($class) = @_;
    my $self = [];
    if( ref $class ) {
        $self = $class;
        $class = ref $class;
    }

    my @config = (
       $class->_tap_name() => { } 
    );

    return @config;
}

sub deselect {
    my ($self) = @_;

    $self->[HANDLE] = undef;

    return 1;
}

sub select {
    my ($self) = @_;

    if( $self->[HANDLE] ) {
        $self->deselect();
    }

    $self->[HANDLE] = \*STDERR;

    return $self;
}

sub gen_output_function {
    my ($self) = @_;

    return sub {
        my ($level, $message ) = @_;
        my $fh = $self->[HANDLE]
            or die "No output filehandle";

        $fh->printflush(@_);
        return;
    };
}
__PACKAGE__;
