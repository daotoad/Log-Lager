#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

use Test::More tests => 1;
use Log::Lager;

my $config = Log::Lager->get_config();
Log::Lager->set_config($config);
my $round_trip = Log::Lager->get_config($config);
is_deeply( $config, $round_trip, 'DEFAULT Round trip OK' );

