#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

use Log::Lager::Tap::File;
use Log::Lager::Message;

my $pkg = 'Log::Lager::Tap::File';

can_ok(
    $pkg,
    qw/ new select deselect dump_config gen_output_function /
);

subtest 'Verify constructor behavior' => sub {
    
    {   my $desc = 'new() requires file_name';

        eval { $pkg->new(); fail("$desc: did not die");1 }
        or do { pass( "$desc - $@" ) };
    }
    
    {   my $desc = 'new() allows file_name';

        my $o;
        eval { 
            $o = $pkg->new( file_name => 'foo' )
                or die("returned false");
            pass( $desc ) if $o->isa( $pkg );
            1;
        } or do { fail( "$desc: died with message - $@" ) };

    }

    {   my $desc = 'new() allows file_name and permissions';

        my $o;
        eval { 
            $o = $pkg->new( file_name => 'foo', permissions => '777' )
                or die("returned false");
            pass( $desc ) if $o->isa( $pkg );
            1;
        } or do { fail( "$desc: died with message - $@" ) };

    }

     {   my $desc = 'new() rejects other parameters';

        eval {
           $pkg->new( filename => 'foo', foo => 'bar' );
           fail("$desc: did not die");
           1
       } or do { pass( "$desc - $@" ) };
    }


};

subtest 'Verify dump_config' => sub {
# TODO
# class method  - default/nulls
# instance method - current values

    {   my $desc = "Call dump config works as a class method";

        my @cfg = $pkg->dump_config();

        is_deeply(
            [ File => { file_name => undef, permissions => undef } ],
            \@cfg,
            $desc
        );

    }

    {   my $desc = "Call dump config works as an instance method";
        my $name = 'foo';
        my $perms = '0775';

        my @cfg = $pkg->new( file_name => $name, permissions => $perms )
                      ->dump_config();

        is_deeply(
            [ File => { file_name => $name, permissions => $perms } ],
            \@cfg,
            $desc
        );

    }
};

subtest 'Verify logging behaviors' => sub {
    my $desc = "";
    $DB::single=1;
    
    local $Log::Lager::Tap::File::DEFAULT_CHECK_FREQUENCY = 0;
    my $any_good_path = 'test-log-file.06';
    my $any_level = 'F';
    my $any_message = "This is a message.";
    eval {
        my $any_other_message = "This, too, is a message.";
        my $any_exception = bless {}, "MyTest::Exception";

    $DB::single=1;
        if( -e $any_good_path ) {
            unlink $any_good_path
                or die "Error deleting file - $any_good_path - $!";
        }

        my $obj = Log::Lager::Tap::File->new(
                file_name => $any_good_path,
            );

        my $out = $obj->gen_output_function();

        $obj->select();
        ok( -e $any_good_path, "Log file created" );

        $out->($any_level, $any_message);

        ok( file_has_message( $any_good_path, $any_message ),
            "Log file has message text"
        );

        unlink $any_good_path
            or die "Error deleting file - $any_good_path - $!";
        
        $out->($any_level, $any_message);


        ok( -e $any_good_path, "New log file created on check" );

        ok( file_has_message( $any_good_path, $any_message ),
            "New log file created on check time got message text"
        );

        1;
    } or die $@;

    unlink $any_good_path
        or die "Error deleting file - $any_good_path - $!";
};

done_testing();



sub file_has_message {
    my ( $path, $message ) = @_;

    open( my $fh, '<', $path)
        or return 0;

    my $file_contents = join "", <$fh>;

    $file_contents =~ /$message/;
}

