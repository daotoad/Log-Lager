package Log::Lager::Spitter::StdErr;

use strict;
use warnings;

our @ISA = Log::Lager::Spitter::FileHandle;

sub new {
    my ( $class ) = @_;
    require Log::Lager::Spitter::FileHandle;
    return $class->SUPER::new( file_handle => *STDERR );
}

sub config_matches {
    my $self = shift;
    my $options = shift;

    # No options to configure
    return !%$options;
}

1;
