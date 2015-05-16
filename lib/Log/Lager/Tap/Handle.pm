package Log::Lager::Tap::Handle;
our @ISA = qw< Log::Lager::Tap >;

use strict;
use warnings;
use Carp qw( croak );
$Carp::Internal{__PACKAGE__}++;

use constant STAT_INODE => 1;

use constant {
    HANDLE      => 0,
    TO_OPEN     => 1,
    TO_CLOSE    => 2,
    TO_CHECK    => 3,
    CHECK_FREQ  => 4,
    NEXT_CHECK  => 5,
};

our $DEFAULT_CHECK_FREQUENCY = 60;

sub new {
    my ($class, %opt) = @_;

    my $self = bless [], $class;
    $self->[TO_OPEN]    = delete $opt{open};
    $self->[TO_CLOSE]   = delete $opt{close};
    $self->[TO_CHECK]   = delete $opt{check};
    $self->[CHECK_FREQ] = delete $opt{check_interval} // $DEFAULT_CHECK_FREQUENCY;
    $self->[NEXT_CHECK] = 0;

    my @bad = sort keys %opt;
    croak "Invalid parameters for new Log::Lager::Tap::Handle - @bad"
        if @bad;

    {   no strict 'refs';
        $self->[$_] = \&{"$self->[$_]"}
            for grep !ref( $self->[$_] ),
                grep defined $self->[$_], 
                TO_OPEN, TO_CLOSE, TO_CHECK;
    }

    return $self;
}

sub get_handle {
    my ($self) = @_;
    return $self->[HANDLE];
}

sub dump_config {
    my ($class) = @_;
    my $self = [];
    if( ref $class ) {
        $self = $class;
        $class = ref $class;
    }
    my $tap = $class;
    $tap =~ s/^Log::Lager::Tap:://;

    my @config = (
        $tap => {
            open => $self->[TO_OPEN],
            close => $self->[TO_CLOSE],
            check => $self->[TO_CHECK],
            check_interval => $self->[CHECK_FREQ],
       },
    );

    return @config;
}

sub deselect {
    my ($self) = @_;

    my $old_handle = $self->[HANDLE];
    $self->[HANDLE]     = undef;
    $self->[NEXT_CHECK] = 0;

    if( $old_handle ) {
        if( $self->[TO_CLOSE] ) {
            $self->[TO_CLOSE]->($old_handle);
        }
    }

    return 1;
}

sub select {
    my ($self) = @_;

    if( $self->[HANDLE] ) {
        $self->deselect();
    }

    $self->[HANDLE] = $self->[TO_OPEN]->();
    $self->[NEXT_CHECK] = time + $self->[CHECK_FREQ];

    return $self;
}


sub gen_output_function {
    my ($self) = @_;

    return sub {
        my ($level, $event) = @_;

        my $now = time;
        if(  $now >= $self->[NEXT_CHECK] ) {

            
            if ( 
                $self->[TO_CHECK]
                && ! $self->[TO_CHECK]->($self->[HANDLE])
            ) {
                eval {
                    $self->select(); 1
                } or do {
                    my $e = $@;
                    Log::Lager::ERROR("Error reopening log handle", "$e");
                    # TODO  - keep writing to old handle or write to STDERR
                }
            }
        }

        my $fh = $self->[HANDLE] || $Log::Lager::STDERR;

        my $message = $event->format(); 
        $fh->printflush($message);
        return;
    };
}

__PACKAGE__;
