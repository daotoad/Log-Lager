#!/usr/bin/perl 
use feature 'say';

use strict;
use warnings;
use Test::More tests => 21;
#BEGIN { sub Log::Lager::INTERNAL_TRACE () {1} }
use Log::Lager;
use constant CAP => 'Log::Lager::Capture::STDERR';

use Log::Lager 'enable FEWTDIGU';
my $file = __FILE__;

ok( Log::Lager->will_log( 'DEBUG' ), "Will log at DEBUG" );
ok( Log::Lager->will_log( 'WARN' ), "Will log at WARN" );

Log::Lager->configure_tap( Handle => { open => 'main::open_handle' } ); 
{   Log::Lager->configure_capture(
        STDERR => {
            level       => 'WARN',
            dup         => 1,
            msg_class   => 'Custom', 
            msg_config  => {}
        } 
    ); 

    warn "Foo"; my $line = __LINE__;
    print get_log();

    my $entry = get_log();
    like( $entry, qr/Foo/, 'Log entry generated') ;
    like( $entry, qr/ line $line\./, 'Line number correct in string') ;
    like( $entry, qr/, $line,/, 'Line number correct in header') ;
    like( $entry, qr/, "$file",/, 'File name correct in header') ;

    clear_log();

    $line = warned_here( 'Bar' );
    $entry = get_log();
    like( $entry, qr/Bar/, 'Log entry generated') ;
    like( $entry, qr/ line $line\./, 'Line number correct in string') ;
    like( $entry, qr/, $line,/, 'Line number correct in header') ;
    like( $entry, qr/, "$file",/, 'File name correct in header') ;
    clear_log();
}

Log::Lager->configure_tap( Handle => { open => 'main::open_handle' } ); 
{   Log::Lager->configure_capture(
        STDERR => {
            level => 'DEBUG',
            dup => 1,
            msg_class => "Custom",
            msg_config => {},
        }
    ); 

    warn "Foo"; my $line = __LINE__;
    print get_log();

    my $entry = get_log();
    like( $entry, qr/Foo/, 'Log entry generated') ;
    like( $entry, qr/DEBUG/, 'Logged as DEBUG') ;
    like( $entry, qr/ line $line\./, 'Line number correct in string') ;
    like( $entry, qr/, $line,/, 'Line number correct in header') ;
    like( $entry, qr/, "$file",/, 'File name correct in header') ;
    clear_log();
    use Log::Lager 'disable D';
    ok( !Log::Lager->will_log( 'DEBUG' ), "Will not log at DEBUG" );

    is( get_log(), '', 'Did not log when level disabled') ;
}

Log::Lager->configure_default_message( Custom => {} );
{   Log::Lager->configure_capture(
        STDERR => {
            level       => 'WARN',
            dup         => 1,
        } 
    ); 

    warn "Foo"; my $line = __LINE__;
    print get_log();

    my $entry = get_log();
    like( $entry, qr/Foo/, 'Log entry generated') ;
    like( $entry, qr/ line $line\./, 'Line number correct in string') ;
    like( $entry, qr/, $line,/, 'Line number correct in header') ;
    like( $entry, qr/, "$file",/, 'File name correct in header') ;
    clear_log();
}




sub warned_here {
    warn @_;
    return __FILE__, __LINE__-1;
}

BEGIN {
    package Log::Lager::Message::Custom;
    use Log::Lager::InlineClass;
    our @ISA = 'Log::Lager::Message';
    sub _header { print "LOGGING\n"; [ "LLMC", @{ $_[0]->SUPER::_header()} ] } 
}

{   my $log;
    my $fh;

    sub get_handle { $fh }

    sub open_handle {
        $log = '';
        open $fh, '>', \$log
            or die "error opening handle to variable $!\n";
        return $fh;
    }

    sub get_log {
        my $result = $log;
        return $result;
    }
    
    sub clear_log {
        $fh->seek(0,0);
        $log = '';
    }
}
