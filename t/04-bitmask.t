#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

use Test::More tests => 3;

#sub Log::Lager::INTERNAL_TRACE () {1};

use_ok( 'Log::Lager' ) or BAIL_OUT("Error loading Log::Lager.");

# {
#     F => [ 0, 0, 0, 0 ],
#     E => [ 0, 0, 0, 0 ],
#     W => [ 0, 0, 0, 0 ],
#     I => [ 0, 0, 0, 0 ],
#     D => [ 0, 0, 0, 0 ],
#     T => [ 0, 0, 0, 0 ],
#     G => [ 0, 0, 0, 0 ],
# };


testbits( "Default values.", [
       #on die pretty stack
    F => [ 1, 1, 0, 0 ],
    E => [ 1, 0, 0, 0 ],
    W => [ 1, 0, 0, 0 ],
    I => [ 0, 0, 0, 0 ],
    D => [ 0, 0, 0, 0 ],
    T => [ 0, 0, 0, 0 ],
    U => [ 0, 0, 0, 0 ],
    G => [ 0, 0, 0, 0 ],
]);

SKIP: {
  skip "lexical not supported before perl 5.9", 1 unless $] >= 5.009;

  use Log::Lager  'enable FEWIDTUG pretty FEWIDTUG';
testbits( "Lexical values applied.", [
       #on die pretty stack
      F => [ 1, 1, 1, 0 ],
      E => [ 1, 0, 1, 0 ],
      W => [ 1, 0, 1, 0 ],
      I => [ 1, 0, 1, 0 ],
      D => [ 1, 0, 1, 0 ],
      T => [ 1, 0, 1, 0 ],
      U => [ 1, 0, 1, 0 ],
      G => [ 1, 0, 1, 0 ],
  ]);
}


sub testbits {
    my ( $name, $expected ) = @_;
    my @expected = @$expected;

    subtest $name => sub {
        my $got_bits = get_bits(5);
        while (@expected) {
            my $level    = shift @expected;
            my $exp_bits = shift @expected;

            subtest "Bits for level $level" => sub {
                is( $got_bits->{$level}[0], $exp_bits->[0],
                    'ON bit '.($exp_bits->[0] ? 'set' : 'clear')
                );
                is( $got_bits->{$level}[1], $exp_bits->[1],
                    'DIE bit '.($exp_bits->[1] ? 'set' : 'clear')
                ); 
                is( $got_bits->{$level}[2], $exp_bits->[2],
                    'PRETTY bit '.($exp_bits->[2] ? 'set' : 'clear')
                ); 
                is( $got_bits->{$level}[3], $exp_bits->[3],
                    'STACK bit '.($exp_bits->[3] ? 'set' : 'clear')
                ); 
            };
        }
    };
}

sub get_bits {
    my ($level) = @_;

#    print  "BITFLAG: ".Log::Lager::BITFLAG()."\n";
#    printf "$_ MASKBITS: %08X\n", $Log::Lager::MASK_CHARS{$_}[Log::Lager::BITFLAG()]
#       for qw/ F E W I D T G /;

    $level += 2;
    my %bits = map {
        $_ => [
            Log::Lager::_get_bits($level, $Log::Lager::MASK_CHARS{$_}[Log::Lager::BITFLAG()])
        ] 
    } qw/ F E W I D T U G /;

#    use Data::Dumper;
#    print Dumper \%bits;
    return \%bits;
}

1;
