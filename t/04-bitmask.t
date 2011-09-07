#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 3;

#sub Log::Lager::INTERNAL_TRACE () {1};

use_ok( 'Log::Lager' ) or BAIL_OUT("Error loading Log::Lager.");

{
    F => [ 0, 0, 0, 0 ],
    E => [ 0, 0, 0, 0 ],
    W => [ 0, 0, 0, 0 ],
    I => [ 0, 0, 0, 0 ],
    D => [ 0, 0, 0, 0 ],
    T => [ 0, 0, 0, 0 ],
    G => [ 0, 0, 0, 0 ],
};

# Check default mask
    #$on_bit, $die_bit, $pretty_bit, $stack_bit;
is_deeply( get_bits(), {
    F => [ 1, 1, 0, 0 ],
    E => [ 1, 0, 0, 0 ],
    W => [ 1, 0, 0, 0 ],
    I => [ 0, 0, 0, 0 ],
    D => [ 0, 0, 0, 0 ],
    T => [ 0, 0, 0, 0 ],
    G => [ 0, 0, 0, 0 ],
}, "Default values." );

SKIP: {
  skip "lexical not supported before perl 5.9", 1 unless $] >= 5.009;

  use Log::Lager  'lexical enable FEWIDTG pretty FEWIDTG';
  is_deeply( get_bits(), {
      F => [ 1, 1, 1, 0 ],
      E => [ 1, 0, 1, 0 ],
      W => [ 1, 0, 1, 0 ],
      I => [ 1, 0, 1, 0 ],
      D => [ 1, 0, 1, 0 ],
      T => [ 1, 0, 1, 0 ],
      G => [ 1, 0, 1, 0 ],
  }, "Lexical values applied." );
}



sub get_bits {

#    print  "BITFLAG: ".Log::Lager::BITFLAG()."\n";
#    printf "$_ MASKBITS: %08X\n", $Log::Lager::MASK_CHARS{$_}[Log::Lager::BITFLAG()]
#       for qw/ F E W I D T G /;

    my %bits = map {
        $_ => [
            Log::Lager::_get_bits(1, $Log::Lager::MASK_CHARS{$_}[Log::Lager::BITFLAG()])
        ] 
    } qw/ F E W I D T G /;

#    use Data::Dumper;
#    print Dumper \%bits;
    return \%bits;
}

1;
