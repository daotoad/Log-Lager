#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 3;
use_ok( 'Log::Lager::Message' )
    or BAIL_OUT("Unable to load module under test");

can_ok( 'Log::Lager::Message', qw/ new _init
    loglevel    message    hostname    executable
    process_id  thread_id  type        timestamp 
    context_id  callstack  subroutine  package
/ );


my $m = Log::Lager::Message->new(
   loglevel => 'FATAL', 
   message  => [ 'food', ' is', ' good' ],
   context  => 0,
);

isa_ok( $m, 'Log::Lager::Message' );

