package Log::Lager::Tap::STDERR;
our $STDERR; BEGIN { $STDERR = \STDERR };
our @ISA = qw< Log::Lager::Tap >;

use strict;
use warnings;
use Carp qw( croak );
$Carp::Internal{__PACKAGE__}++;


use constant {
    HANDLE      => 0,
    RESTORE     => 1,
};

sub new {
    my ($class, %opt) = @_;

    my $restore = delete $opt{restore};

    my $self = bless [], $class;

    $self->[RESTORE] = $restore;

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
    my $restore = $self->[RESTORE];
    my $tap = $class;
    $tap =~ s/^Log::Lager::Tap:://;

    my @config = (
       $tap => { restore => $restore } 
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

    $self->[HANDLE] = $self->[RESTORE] ? $STDERR : \*STDERR;

    return $self;
}

sub gen_output_function {
    my ($self) = @_;

    return sub {
        my ($level, $fatal, $message ) = @_;
        my $fh = $self->[HANDLE]
            or die "No output filehandle";

        my $msg = $message->format() || '';
        $fh->printflush($msg);
        die "$msg\n" if $fatal;
        return;
    };
}
__PACKAGE__;
