use strict;
use warnings;
#sub Log::Lager::INTERNAL_TRACE  { 1 };

use Log::Lager {
    package_masks => {
        main => 'enable T pretty T',
    },
}; # 'FEWTDIGU';

TRACE  qw( starting up now ) ;

sub foo {
INFO "Do wop she bop";
{   #no Log::Lager 'T';

    DEBUG "Beginning to do something.";

    WARN "I could die";
    eval {
        TRACE 'I am a happy bunny';
        FATAL "Set inner result";
        die "Bella Lugosi is dead.";

    };

    TRACE "Set outer result";
};

}

foo();
TRACE "All Done";
