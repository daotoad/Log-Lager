#!/usr/bin/perl 
use strict;
use warnings;

use lib 'lib';
use Log::Lager 'file test.log base enable FEWTDIG';


INFO "Starting up.";

my %d = (
    time => time(),
    fh_inode => $Log::Lager::OUTPUT_FILE_INODE,
    name_inode => [stat 'test.log']->[1],
);

my $time = time;
while(1) {

    sleep 15;

    $d{time}       = time;
    $d{name_inode} = [stat 'test.log']->[1],
    $d{fh_inode}   = $Log::Lager::OUTPUT_FILE_INODE,

    DEBUG "LOOP - ",\%d;
}
