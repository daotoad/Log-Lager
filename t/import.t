#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Digest::MD5 'md5_hex';



log_function_import_ok( 
    command => '',
    imports => [qw/ FATAL ERROR WARN TRACE INFO DEBUG GUTS UGLY /],
    name    => 'Default imports'
);

log_function_import_ok( 
    command => '[]',
    imports => [],
    name    => 'Empty import array'
);

log_function_import_ok( 
    command => '[ qw/DEBUG GUTS UGLY/ ]',
    imports => [qw/ DEBUG GUTS UGLY /],
    name    => 'Import array with partial import'
);

log_function_import_ok( 
    command => '[ [ DEBUG => "debug" ] ]',
    imports => [qw/ debug  /],
    name    => 'Import renamed function',
);


log_function_import_ok( 
    command   => '[ ], [ ]',
    exception => [qr/array/i, qr/single/i],
    name      => 'Double array spec is fatal',
);

done_testing();




sub log_function_import_ok {
    my %opt = @_;
    my $command     = delete $opt{command};
    my $expected    = delete $opt{imports};
    my $exception   = delete $opt{exception};
    my $name        = delete $opt{name} // "Imported expected functions";

    my $digest = md5_hex( $name . time() );
    my $package = "My::Pack_$digest";

    subtest $name => sub {
        my $died;
        my $code = qq{
            package $package;
            use Log::Lager $command;
        };
        eval $code or do {
            $died = $@;
        };


        if ( $exception ) {
            like( $died, $_ ) for 'ARRAY' eq ref $exception ? (@$exception) : ($exception)
        }
        elsif ( $died ) {
            fail( 'Unexpected exception' );
            diag $code;
            diag $died;
        }

        if ($expected) {
            no strict 'refs';
            my @functions = sort grep $package->can($_), keys %{"${package}::"};
            my @expected = sort @$expected;

            is_deeply( \@functions, \@expected, $name ) or diag( "Got: @functions Expected: @expected");
        }

    };

    return;
}
