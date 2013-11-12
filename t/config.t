#!/usr/bin/perl

use Test::More;

use Log::Lager;
use Data::Dumper;
subtest "Everything on" => sub {
    $DB::single=1;
    Log::Lager->apply_config({
            levels => {base => <<BASE},
enable FEWTDIGU pretty FEWTDIGU fatal FEWTDIGU stack FEWTDIGU
BASE
    });
    my $cfg = Log::Lager->dump_config();
    diag Dumper $cfg;
    ok( $cfg->{lexical_control}, "Lexical controls are enabled" );

    log_level_ok( $cfg->{levels}{base},
        {   enable   => 'FEWTDIGU',
            disable  => '',
            pretty   => 'FEWTDIGU',
            compact  => '',
            stack    => 'FETWDIGU',
            nostack  => '',
            fatal    => 'FEWTDIGU',
            nonfatal => '',
        },
        "Base levels FEW enabled"
    );
    ok( ! %{$cfg->{levels}{package}}, "Package level hash is empty" );
    ok( ! %{$cfg->{levels}{sub}},     "Sub level hash is empty"     );

    is_deeply( $cfg->{message}, { Log::Lager::Message => {} }, "Message is LLM" );
    is_deeply( $cfg->{tap}, { Log::Lager::Tap::STDERR => {} }, "Tap is STDERR" );
};

subtest "Default configuration is correct" => sub {

    Log::Lager->apply_config({});
    my $cfg = Log::Lager->dump_config();
    diag Dumper $cfg;
    ok( $cfg->{lexical_control}, "Lexical controls are enabled" );

    log_level_ok( $cfg->{levels}{base},
        {   enable   => 'FEW',
            disable  => 'TDIGU',
            pretty   => '',
            compact  => 'FEWTDIGU',
            stack    => '',
            nostack  => 'FEWTDIGU',
            fatal    => 'F',
            nonfatal => 'EWTDIGU',
        },
        "Base levels FEW enabled"
    );
    ok( ! %{$cfg->{levels}{package}}, "Package level hash is empty" );
    ok( ! %{$cfg->{levels}{sub}},     "Sub level hash is empty"     );

    is_deeply( $cfg->{message}, { Log::Lager::Message => {} }, "Message is LLM" );
    is_deeply( $cfg->{tap}, { Log::Lager::Tap::STDERR => {} }, "Tap is STDERR" );
};

done_testing();




sub log_level_ok {
    my ($got, $want, $name) = @_;
    diag "GOT $got";

    my @tokens = split /\s+/, $got;
    
    my $mode = '';
    my %level = '';
    while( @tokens ) {
        my $token = shift @tokens;
        diag "$token";
        if( exists $want->{$token} ) {
            # Save uncleared levels
            $want->{$mode} = join //, keys %level;

            # Start processing new mode
            $mode = $token;
            my $level = delete $want->{$token};
            %level = map { $_ => 1 } split //, $level;
        }
        else {
            subtest "$mode has expected levels" => sub {
                my @got = split //, $token;
                diag "@got";
                for my $got_level ( @got ) {
                    if( delete $level{$got_level} ) {
                        pass( "Got expected level '$got_level'" );
                    }
                    else {
                        fail( "Found unexpected level '$got_level'" );
                    }
                }
                done_testing();
            };
        }
    }

    subtest "All expected levels found" => sub {
        my @expected_modes = keys %$want;

        if( @expected_modes ) {
            for my $mode ( keys %$want ) {
                subtest "Unmatched expected levels in mode" => sub {
                    if( length $want->{$mode} ) {
                        fail( "Unmatched expected levels '$want->{$mode}' found in $mode" );
                    } else { 
                        pass( "No unmatched expected levels found in $mode" );
                    }
                };
            }
        }
        else {
            pass( "No unmatched expected levels found" );
        }
        done_testing();
    }


}
