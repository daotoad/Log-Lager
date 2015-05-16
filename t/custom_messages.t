#!/usr/bin/perl 

use strict;
use warnings;
use Test::More tests => 3;
use Log::Lager;

BEGIN {
    package Log::Lager::Event::Custom;
    use Log::Lager::InlineClass;
    our @ISA = 'Log::Lager::Event';
    sub format { return __PACKAGE__ }

    package LLE::Custom;
    use Log::Lager::InlineClass;
    our @ISA = 'Log::Lager::Event';

    sub format { return __PACKAGE__ }
}

{   Log::Lager->configure_tap( Handle => { open => 'main::open_handle' } ); 
    Log::Lager->configure_default_event( 'Custom', {} );
    WARN "Event";
    is get_log(), 'Log::Lager::Event::Custom', "Loaded custom event class";
}
    
{   Log::Lager->configure_tap( Handle => { open => 'main::open_handle' } ); 
    Log::Lager->configure_default_event( 'LLE::Custom' => {} );
    WARN "Event";
    is get_log(), 'LLE::Custom', "Loaded custom event class";
}


{   Log::Lager->configure_tap( Handle => { open => 'main::open_handle' } ); 
    Log::Lager->configure_default_event( 'Log::Lager::Event::Custom', {} );
    WARN "Event";
    is get_log(), 'Log::Lager::Event::Custom', "Loaded custom event class";
}
    

{   my $log;
    sub open_handle {
        open my $fh, '>', \$log
            or die "error opening handle to variable $!\n";
        return $fh;
    }
    sub get_log {
        my $result = $log;
        return $result;
    }
}



