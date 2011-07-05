#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 29;

use File::Temp;
use JSON;

my @TEST_SPECS  = (
    [ 'use FEWTDIG' => [
            [ FATAL   => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ ERROR   => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ WARNING => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ TRACE   => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ DEBUG   => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ INFO    => { enabled => 1, fatal => 0, stack_trace => 0 } ],
            [ GUTS    => { enabled => 1, fatal => 0, stack_trace => 0 } ],
        ],
    ],

    [ 'use FEWTDIG stack FEWTDIG' => [
            [ FATAL   => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ ERROR   => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ WARNING => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ TRACE   => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ DEBUG   => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ INFO    => { enabled => 1, fatal => 0, stack_trace => 1 } ],
            [ GUTS    => { enabled => 1, fatal => 0, stack_trace => 1 } ],
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

    my $foo = <>;
}



sub exec_loglevel {
    my $lexical_cmd = shift;
    my $level = shift;
    
    my $fh = File::Temp->new( DIR => "t" );
    my $path = $fh->filename;

    diag( $path );

    my $cut = <<"END";
    $lexical_cmd;
    use Log::Lager file $path;

    

    $fh->printflush("BEGIN MESSAGE\n");
    eval { $level 'Message'; 1 }
    or $fh->printflush("Exception thrown\n");
    $fh->printflush("END MESSAGE\n");
    
    1;
END

    eval $cut;

    $fh->seek(0, 0);

    my @result = $fh->getlines;

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
              : $expect->{fatal}    ? 1
              :                       0;
    is( scalar @except, $count, 'Exceptions as configured.' );
    
    my $json = $results->[1];

    # TODO parse etc.

}
