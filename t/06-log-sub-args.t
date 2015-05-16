#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 13;
use Log::Lager;

Log::Lager->configure_tap( Handle => { open => 'main::open_handle' } ); 


my $log;
sub open_handle {
    open my $fh, '>', \$log
        or die "error opening handle to variable $!\n";
    return $fh;
}

{   use Log::Lager "enable FEWTDIG";
    my $called = 0;
    ERROR sub {
        $called++;
        return "Logged";
    };
    ok $called, "Code called when log level is enabled";
    like $log, qr"Logged";
    $log = '';
}

{   use Log::Lager "disable FEWTDIG";
    my $called = 0;
    ERROR sub {
        $called++;
        return "Logged";
    };
    ok !$called, "Code not called when log level is disabled";
    unlike $log, qr"Logged";
    $log = '';
}


{   use Log::Lager "enable FEWTDIG";
    my $msg = Log::Lager::Event->new(
        body => [ "Logged" ],
        return_result => [ 12321 ],
        context => 0,
    );
    my $returned = ERROR( $msg );
    like $log, qr"Logged", "Event logged when enabled";
    is $returned, 12321, "Return value passed when enabled";
    $log = '';
}

{   use Log::Lager "disable FEWTDIG";
    my $msg = Log::Lager::Event->new(
        body => [ "Logged" ],
        return_result => [ 12321 ],
        context => 0,
    );
    my $returned = ERROR( $msg );
    unlike $log, qr"Logged", "Event not logged when disabled";
    is $returned, 12321, "Return value passed when disabled";
    $log = '';
}

{   use Log::Lager "enable FEWTDIG fatal FEWTDIGU";

    my $msg = Log::Lager::Event->new(
        body => [ "Logged" ],
        return_exception => "Shit is broke",
        context => 0,
    );
    eval {
        ERROR( $msg );
        fail('Did not throw exception');
    } or do {
        pass('Threw exception');
        like $@, qr"Shit is broke";
    };
    like $log, qr"Logged", "Event logged when enabled";
    $log = '';
}

{   use Log::Lager "disable FEWTDIG";

    my $msg = Log::Lager::Event->new(
        body => [ "Logged" ],
        return_exception => undef,
        context => 0,
    );
    eval {
        ERROR( $msg );
        pass('Did not throw exception');
    } or do {
        fail('Threw exception');
    };
    unlike $log, qr"Logged", "Event not logged when disabled";
    $log = '';
}

done_testing();
