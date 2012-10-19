package Log::Lager::Spitter::StdOut;
use strict;
use warnings;

our @ISA = Log::Lager::Spitter::FileHandle;

sub new {
    my ( $class ) = @_;
    require Log::Lager::Spitter::FileHandle;
    return Log::Lager::Spitter::FileHandle->new(
        file_handle => *STDOUT
    );
}

sub config_matches {
    my $self = shift;
    my $options = shift;

    # No options to configure
    return !%$options;
}

1;
