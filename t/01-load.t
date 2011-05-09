#!/site/perl/perl-5.10.1-1/bin/perl -w
use strict;
use warnings;
use lib '../../../../lib';

use Test::More tests => 24;

use_ok( 'Log::Lager' );


my @LOG_LEVELS = (
    [ F => FATAL => 0x01 ],
    [ E => ERROR => 0x02 ],
    [ W => WARN  => 0x04 ],
    [ I => INFO  => 0x08 ],
    [ D => DEBUG => 0x10 ],
    [ T => TRACE => 0x20 ],
    [ G => GUTS  => 0x40 ],
);

for ( @LOG_LEVELS ) {
    my ($char, $value) = @{$_}[0,2];
    is( Log::Lager::_bitmask_to_mask_string( $value, 0 ), $char, "Mask for $char correct" );
    is( Log::Lager::_bitmask_to_mask_string( $value<<16, 16  ), $char, "Shifted mask for $char correct" );
}
is( Log::Lager::_bitmask_to_mask_string( 0xFF, 0 ), 'FEWIDTG', "Mask for FEWIDTG correct" );



for ( @LOG_LEVELS ) {
    my ($char, $value) = @{$_}[0,2];
    is( Log::Lager::_mask_string_to_bitmask( $char ), $value, "Mask for $char correct" );
}
is( Log::Lager::_mask_string_to_bitmask( 'FEWIDTG' ), 0x7F, "Mask for FEWIDTG correct" );



