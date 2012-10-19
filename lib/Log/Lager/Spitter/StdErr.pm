package Log::Lager::Spitter::StdErr;

use strict;
use warnings;

our @ISA = 'Log::Lager::Spitter::FileHandle';

our $IDENTITY_OPTIONS = [ qw<
> ];
our $OPTION_ATTRIBUTE_INDEX_MAP = {
};

sub new {
    my ( $class ) = @_;
    require Log::Lager::Spitter::FileHandle;
    return $class->SUPER::new( file_handle => *STDERR );
}

# should we close the filehandle on _DESTROY() ?

1;
