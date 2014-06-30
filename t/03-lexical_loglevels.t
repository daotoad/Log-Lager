#!/usr/bin/perl
use strict;
use warnings;

my @useargs;
BEGIN {
    @useargs = $] < 5.009 ? ( skip_all => "Ancient Perl doesn't do lexical logging" ) : ( tests => 4 );
}
use Test::More @useargs;

use File::Temp;
use JSON::XS;
use Data::Dumper;

sub Log::Lager::INTERNAL_TRACE() {1};

BEGIN { package _My_::Test; use Log::Lager; }

my @TEST_SPECS  = (
    [ 'use Log::Lager "FEWTDIG nonfatal FEWTDIG nostack FEWTDIG"' => [
            [ FATAL   => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ ERROR   => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ WARN    => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ TRACE   => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ DEBUG   => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ INFO    => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ GUTS    => { enabled => 1, fatal => 0, stack_trace => 0 } ],
        ],
    ],

    [ 'use Log::Lager "FEWTDIG nonfatal FEWTDIG pretty FEWTDIG"' => [
            [ FATAL   => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ ERROR   => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ WARN    => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ TRACE   => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ DEBUG   => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ INFO    => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ GUTS    => { enabled => 1, fatal => 0, stack_trace => 1 } ],
        ],
    ],

    [ 'use Log::Lager "FEWTDIG fatal FEWTDIG pretty FEWTDIG"' => [
            [ FATAL   => { enabled => 1, fatal => 1, stack_trace => 1 } ],
            [ ERROR   => { enabled => 1, fatal => 1, stack_trace => 1 } ],
            [ WARN    => { enabled => 1, fatal => 1, stack_trace => 1 } ],
            [ TRACE   => { enabled => 1, fatal => 1, stack_trace => 1 } ],
            [ DEBUG   => { enabled => 1, fatal => 1, stack_trace => 1 } ],
            [ INFO    => { enabled => 1, fatal => 1, stack_trace => 1 } ],
            [ GUTS    => { enabled => 1, fatal => 1, stack_trace => 1 } ],
        ],
    ],
);



require_ok( 'Log::Lager' ) 
    or BAIL_OUT('Error loading Log::Lager');


run_test_group();

sub run_test_group {
    for my $set_spec ( @TEST_SPECS ) {
        my ($cmd, $set) = @$set_spec;

        subtest $cmd, sub {

            for my $test ( @$set ) {
                my ($level, $expect) = @$test;
            
                my $result = exec_loglevel( $cmd, $level );
                check_results( $result, $expect, $level );
            }
        };
    }
}



sub exec_loglevel {
    my $lexical_cmd = shift;
    my $level = shift;

    my $path = 't/logfile';

    {   open my $fh, '>', $path;
        $fh->printflush("BEGIN MESSAGE\n");
    }
    
    my $cut = <<"END";
    package _My_::Test;
    use Log::Lager;
    no warnings 'redefine';
    Log::Lager->set_config({
        lexical_control => 1,
        tap => { File => { file_name => '$path' } }
    });

    log_me();

    sub log_me {
        $lexical_cmd;
        $level 'Message'; 
    }

    1;
    
END

    eval $cut or do { 
        open my $fh, '>>', $path;
        $fh->printflush("Exception thrown - $@\n");
    };

    {   open my $fh, '>>', $path;
        $fh->printflush("END MESSAGE\n");
    }

    my @result = do {
        open my $fh, '<', $path;
        $fh->getlines;
    };


    unlink $path or die "Error deleting file '$path' - $!\n";

    return \@result;
}

sub check_results {
    my $results = shift;
    my $expect  = shift;
    my $level   = shift;

    subtest "Checking level $level", sub { 

        my $cmp = ! $expect->{enabled}   ? '<'
                : $expect->{stack_trace} ? '>'
                :                          '==';
        cmp_ok( scalar @$results, $cmp, 3, 'Emitted line count as configured.' );
        
        my @except = grep /Exception thrown/,  @$results;

        if( $expect->{enabled} && $expect->{fatal} ) {
            is( scalar @except, 1, "Got expected exception" );
        }
        else {
            is( scalar @except, 0, "No unexpected exceptions" );
            diag( @except ) if @except;
        }
        
        my $json = $results->[1];

        # TODO parse etc.
    } or diag Dumper $results;

    #diag "===================================================";

}

BEGIN {
    package BOOGER;
    use base 'Log::Lager::Message';
}
