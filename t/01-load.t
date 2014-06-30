#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 26;
use Log::Lager;



my @LOG_LEVELS = (
    [ F => FATAL => 0x01 ],
    [ E => ERROR => 0x02 ],
    [ W => WARN  => 0x04 ],
    [ I => INFO  => 0x08 ],
    [ D => DEBUG => 0x10 ],
    [ T => TRACE => 0x20 ],
    [ G => GUTS  => 0x40 ],
    [ U => UGLY  => 0x80 ],
);

for ( @LOG_LEVELS ) {
    my ($char, $value) = @{$_}[0,2];
    is( Log::Lager::_bitmask_to_mask_string( $value, 0 ), $char, "Mask for $char correct" );
    is( Log::Lager::_bitmask_to_mask_string( $value<<16, 16  ), $char, "Shifted mask for $char correct" );
}
is( Log::Lager::_bitmask_to_mask_string( 0xFF, 0 ), 'FEWIDTGU', "Mask for FEWIDTGU correct" );



for ( @LOG_LEVELS ) {
    my ($char, $value) = @{$_}[0,2];
    is( Log::Lager::_mask_string_to_bitmask( $char ), $value, "Mask for $char correct" );
}
is( Log::Lager::_mask_string_to_bitmask( 'FEWIDTGU' ), 0xFF, "Mask for FEWIDTGU correct" );



