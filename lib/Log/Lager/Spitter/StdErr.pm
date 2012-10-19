package Log::Lager::Spitter::StdErr;
use strict;
use warnings;

sub new {
    my ( $class ) = @_;
    require Log::Lager::Spitter::FileHandle;
    return Log::Lager::Spitter::FileHandle->new(
        file_handle => *STDERR
    );
}

1;
