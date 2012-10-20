use strict;
use warnings;
#sub Log::Lager::INTERNAL_TRACE  { 1 };

use Log::Lager; # 'FEWTDIGU';

TRACE  qw( starting up now ) ;

INFO "Do wop she bop";
{   no Log::Lager 'T';

    DEBUG "Beginning to do something.";

    WARN "I could die";
    eval {
        FATAL "Set inner result";
        die "Bella Lugosi is dead.";

    };

    TRACE "Set outer result";
};


TRACE "All Done";
