#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Log::Lager::Tap::STDERR;

my $pkg = 'Log::Lager::Tap::STDERR';

can_ok(
    $pkg,
    qw/ new select deselect dump_config gen_output_function /
);

subtest 'Verify constructor behavior' => sub {
    
    {   my $desc = 'new() allows restore';

        my $o;
        eval { 
            $o = $pkg->new( restore => 'foo' )
                or die("returned false");
            pass( $desc ) if $o->isa( $pkg );
            1;
        } or do { fail( "$desc: died with message - $@" ) };

    }

    {   my $desc = 'new() does not require restore';

        my $o;
        eval { 
            $o = $pkg->new( )
                or die("returned false");
            pass( $desc ) if $o->isa( $pkg );
            1;
        } or do { fail( "$desc: died with message - $@" ) };

    }

     {   my $desc = 'new() rejects other parameters';

        eval {
           $pkg->new( foo => 'bar' );
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
            \@cfg,
            [ STDERR => { restore => undef } ],
            $desc
        );

    }

    {   my $desc = "Call dump config works as an instance method";

        my @cfg = $pkg->new( restore => 1 )
                      ->dump_config();

        is_deeply(
            \@cfg,
            [ STDERR => { restore => 1 } ],
            $desc
        );

    }
};

subtest 'Verify logging behaviors' => sub {
    my $obj = $pkg->new();
    my $out = $obj->gen_output_function();
    
    pass('TODO');
};

done_testing();



sub file_has_message {
    my ( $path, $message ) = @_;

    open( my $fh, '<', $path)
        or return 0;

    my $file_contents = join "", <$fh>;

    $file_contents =~ /$message/;
}

