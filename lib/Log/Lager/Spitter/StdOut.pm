package Log::Lager::Spitter::StdOut;
use strict;
use warnings;

our @ISA = 'Log::Lager::Spitter::FileHandle';

our $IDENTITY_OPTIONS = [ qw< > ];
our $OPTION_ATTRIBUTE_INDEX_MAP = { };

sub new {
    my ( $class ) = @_;
    require Log::Lager::Spitter::FileHandle;
    return Log::Lager::Spitter::FileHandle->new(
        file_handle => *STDOUT
    );
}

1;
