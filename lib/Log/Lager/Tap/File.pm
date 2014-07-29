package Log::Lager::Tap::File;
our @ISA = qw< Log::Lager::Tap >;

use strict;
use warnings;
use Carp qw( croak );
$Carp::Internal{__PACKAGE__}++;

use constant STAT_INODE => 1;

use constant {
    NAME        => 0,
    PERM        => 1,
    HANDLE      => 2,
    INODE       => 3,
    CHECK_FREQ  => 4,
    NEXT_CHECK  => 5,
};

our $DEFAULT_CHECK_FREQUENCY = 60;

sub new {
    my ($class, %opt) = @_;

    my $self = bless [], $class;
    $self->[NAME] = delete $opt{file_name};
    $self->[PERM] = delete $opt{permissions};
    $self->[CHECK_FREQ] = $DEFAULT_CHECK_FREQUENCY;
    $self->[NEXT_CHECK] = 0;

    my @bad = sort keys %opt;
    croak "Invalid parameters for new Log::Lager::Tap::File - @bad"
        if @bad;

    croak "Required parameter 'file_name' is not defined"
        unless $self->[NAME];

    return $self;
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
           file_name   => $self->[NAME],
           permissions => $self->[PERM],
       } 
    );

    return @config;
}

sub deselect {
    my ($self) = @_;

    my $old_handle = $self->[HANDLE];
    $self->[HANDLE]     = undef;
    $self->[INODE]      = undef;
    $self->[NEXT_CHECK] = 0;

    if( $old_handle ) {
        $old_handle->close()
           or die "Error closing $self->[NAME] - $!\n";
    }

    return 1;
}

sub select {
    my ($self) = @_;

    if( $self->[HANDLE] ) {
        $self->deselect();
    }

    require IO::File;
    my $fh = IO::File->new( $self->[NAME], '>>', $self->[PERM] )
        or die "Error opening $self->[NAME] - $!\n";

    my @file_stat = stat( $self->[NAME] );
    $self->[INODE] = $file_stat[STAT_INODE];
    $self->[NEXT_CHECK] = time + $self->[CHECK_FREQ];
    $self->[HANDLE] = $fh;

    return $self;
}


sub gen_output_function {
    my ($self) = @_;

    return sub {
        my ($level, $fatal, $message ) = @_;

        my $now = time;
        if(  $now >= $self->[NEXT_CHECK] ) {
            #Verify file has not been moved (eg by a log roller)
            my $inode = (stat $self->[NAME] )[STAT_INODE];
            $inode ||= 0;

            if ( $self->[INODE] != $inode
                || ! $self->[HANDLE]
            ) {
                eval { $self->select(); 1
                } or do {
                    my $e = $@;
                    Log::Lager::ERROR("Error reopening log filer", $self->[NAME], "$e");
                    # TODO  - keep writing to old handle or write to STDERR
                }
            }
        }

        my $fh = $self->[HANDLE] || \*STDERR;

        my $msg = $message->format() || '';
        $fh->printflush($msg);
        die "$msg\n" if $fatal;
        return;
    };
}

__PACKAGE__;
