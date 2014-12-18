#!/usr/bin/perl 

use strict;
use warnings;
use Test::More tests => 3;
use Log::Lager;

BEGIN {
    package Log::Lager::Message::Custom;
    use Log::Lager::InlineClass;
    our @ISA = 'Log::Lager::Message';
    sub format { return __PACKAGE__ }

    package LLM::Custom;
    use Log::Lager::InlineClass;
    our @ISA = 'Log::Lager::Message';

    sub format { return __PACKAGE__ }
}

{   Log::Lager->configure_tap( Handle => { open => 'main::open_handle' } ); 
    Log::Lager->configure_default_message( 'Custom', {} );
    WARN "Message";
    is get_log(), 'Log::Lager::Message::Custom', "Loaded custom message class";
}
    
{   Log::Lager->configure_tap( Handle => { open => 'main::open_handle' } ); 
    Log::Lager->configure_default_message( 'LLM::Custom' => {} );
    WARN "Message";
    is get_log(), 'LLM::Custom', "Loaded custom message class";
}


{   Log::Lager->configure_tap( Handle => { open => 'main::open_handle' } ); 
    Log::Lager->configure_default_message( 'Log::Lager::Message::Custom', {} );
    WARN "Message";
    is get_log(), 'Log::Lager::Message::Custom', "Loaded custom message class";
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



