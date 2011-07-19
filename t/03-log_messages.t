#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 43;

use File::Temp;
use JSON;

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



use_ok( 'Log::Lager' ) 
    or BAIL_OUT('Error loading Log::Lager');

for my $set_spec ( @TEST_SPECS ) {
    my ($cmd, $set) = @$set_spec;

    for my $test ( @$set ) {
        my ($level, $expect) = @$test;
    
        my $result = exec_loglevel( $cmd, $level );
        check_results( $result, $expect );
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
    $lexical_cmd;
    use Log::Lager 'file $path';
    use Log::Lager 'stack FEWTDIG';

    log_me();

    sub log_me {
        $level 'Message'; 
    }

    1;
    
END

    print "$cut";

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


    return \@result;
}

sub check_results {
    my $results = shift;
    my $expect  = shift;

    warn "RESULTS:\n@$results\n";

    my $cmp = ! $expect->{enabled}   ? '<'
            : $expect->{stack_trace} ? '>'
            :                          '=';
    cmp_ok( scalar @$results, $cmp, 3, 'Emitted line count as configured.' );
    
    my @except = grep /Exception thrown/,  @$results;

    my $count = !$expect->{enabled} ? 0
              :  $expect->{fatal}   ? 1
              :                       0;
    is( scalar @except, $count, 'Exceptions as configured.' );
    
    my $json = $results->[1];

    # TODO parse etc.

}
