package Log::Lager::Spitter::File;
use strict;
use warnings;

use constant LOG_FILEHANDLE_CHECK_FREQ => 60; # Seconds
use constant STAT_INODE => 1;

# Class attributes:
my @Attrs;
BEGIN {
    require constant;
    @Attrs = qw<
        _filename
        _file_handle
        _file_perm
        _check_time
        _inode
    >;
    for ( 0..$#Attrs ) {
        constant->import( $Attrs[ $_ ], $_ );
    }
}

sub new {
    my( $class, %params ) = @_;

    my $self = bless( [], $class );
    $self->[_filename] = $params{ filename };
    $self->[_file_perm] = $params{ fileperm };
    # TODO: add checks for extraneous params

    return $self->_open_the_file()
        ? $self
        : undef;    # so caller knows we failed
}

sub _open_the_file {
    my ( $self ) = @_;

    require IO::File;
    my @output_stat = stat($self->[_filename]);
    $self->[_file_handle] = IO::File->new(
        $self->[_filename],
        '>>',
        $self->[_file_perm]
    );

    if( $self->[_file_handle] ) {

        my $file_exists = -e $self->[_filename];
        @output_stat = stat($self->[_file_handle])
            unless $file_exists;

        $self->[_inode] = $output_stat[STAT_INODE];
        $self->[_check_time] = time;
    }

    if( ! $self->[_file_handle] ) {
        require Log::Lager;
        Log::Lager::ERROR("Unable to open '$self->[_filename]' for logging.", $!);
    }

    return $self->[_file_handle];
}



sub spit {
    my ($self, $level, $message ) = @_;
    my $message_txt = $message->format();

    if ( $self->[_check_time] + LOG_FILEHANDLE_CHECK_FREQ <= time ) {
        $self->[_check_time] = time;

        my $inode = (stat $self->[_filename])[STAT_INODE];
        $inode = 0 unless $inode;

        if ( ! $self->[_file_handle]
            or $self->[_inode]  != $inode
        ) {
            _open_the_file();
        }
    }

    if( $self->[_file_handle] ) {
        $self->[_file_handle]->printflush( $message_txt );
    }
    else {
        require Log::Lager::Spitter;
        Log::Lager::Spitter->default()->spit( $level, $message_txt );
    }

    return;
}

sub _DESTROY {
    my $self = shift;
    if( $self->[_file_handle] ) {
        require IO::File;
        $self->[_file_handle]->close;
        $self->[_file_handle] = undef;
    }
}

1;
