#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 2;
use_ok( 'Log::Lager::Event' )
    or BAIL_OUT("Unable to load module under test");

my $m = Log::Lager::Event->new(
   loglevel => 'FATAL', 
   body  => [ 'food', ' is', ' good' ],
);

isa_ok( $m, 'Log::Lager::Event' );

done_testing();
