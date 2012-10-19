#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 4;
use Log::Lager::Mask;
use Log::Lager;

{   # Simple constructor
    my $m = Log::Lager::Mask->new();
    isa_ok( $m, 'Log::Lager::Mask' );
}

my @COMMAND = (
     'enable F E W stack DWIT F nostack E',
     'compact F pretty W disable G ',
     'enable FE WI fatal F',
);

my $m;
ok( eval {
    $m = Log::Lager::Mask->parse_command( @COMMAND );
    1;
}, 'Parse command w/o error '. $@ );

isa_ok( $m, 'Log::Lager::Mask');

#is( ''. parse_command("$r"), "$r", 'Round trip OK' );

ok( eval {
    Log::Lager::apply_command( @COMMAND );
    1;
}, "Apply command without error $@" );

if(0) {
    my $log_level = Log::Lager::log_level;
    Log::Lager::apply_command($log_level);
    my $round_trip = Log::Lager::log_level;
    is( $log_level, $round_trip, 'Round trip OK' );

    Log::Lager::apply_command('stderr');
    Log::Lager->apply_command( $log_level );
    my $arrows = Log::Lager->log_level;
    is( $arrows, $round_trip, 'Round trip OK' );

}

