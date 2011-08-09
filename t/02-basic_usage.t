#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 12;

use Log::Lager::CommandParser 'parse_command';
use Log::Lager;

my $cp = Log::Lager::CommandParser->new;
isa_ok( $cp, 'Log::Lager::CommandParser' );
is( $cp->{state},      'start',   'state initialized correctly' );
is( my $state =  $cp->state(), 'start',   'state initialized correctly' );
is( $cp->mask_select,  'lexical', 'mask_select initialized correctly' );
is( $cp->mask_group,   'enable',  'mask_group initialized correctly' );

isa_ok( $cp->result, 'Log::Lager::CommandResult' );

my @COMMAND = (
     'base enable FEW stack DWIT F nostack E',
     'lexical compact F pretty W disable G lexoff',
     'sub Foo::Bar::quix',
     'package Foo::Bar::Baz enable FEWI fatal F',
     'stderr',
     'file  /potato/soup/is/vicious',
);

my $r;
ok( eval {
    $r = parse_command( @COMMAND );
    1;
}, 'Parse command w/o error '. $@ );

isa_ok( $r, 'Log::Lager::CommandResult');

is( ''. parse_command("$r"), "$r", 'Round trip OK' );

ok( eval {
    Log::Lager::apply_command( @COMMAND );
    1;
}, "Apply command without error $@" );

my $log_level = Log::Lager::log_level;
Log::Lager::apply_command($log_level);
my $round_trip = Log::Lager::log_level;
is( $log_level, $round_trip, 'Round trip OK' );

Log::Lager::apply_command('stderr');
Log::Lager->apply_command( $log_level );
my $arrows = Log::Lager->log_level;
is( $arrows, $round_trip, 'Round trip OK' );


