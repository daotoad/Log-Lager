use strict;
use warnings;
sub Log::Lager::INTERNAL_TRACE  { 1 };

use Log::Lager qw( FEWIDTG );

TRACE  qw( starting up now ) ;

INFO "Do wop she bop";
{

    DEBUG "Beginning to do something.";

    eval {
        FATAL "Set inner result";
        die "Bella Lugosi is dead.";

    };

    TRACE "Set outer result";
};


TRACE "All Done";
