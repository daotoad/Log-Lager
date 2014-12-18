#!/usr/bin/perl

use Test::More tests => 6;

use Log::Lager::Util;

use constant LLU => 'Log::Lager::Util';

foo( $_, $_ ) for 0..2;

MyTest::Poop::inline_class( \&foo, 0, 1 );
MyTest::Poop::inline_class( \&foo, 1, 2 );
MyTest::Poop::inline_class( \&foo, 2, 4 );

sub foo {
    my ($lager, $caller, $name ) = @_;
    $name ||= "LLU->caller($lager) matches CORE::caller($caller)";
    is( LLU->caller($lager), caller($caller), $name );
}

BEGIN {
    package MyTest::Poop;
    use Log::Lager::InlineClass;

    sub inline_class {
        my $code = shift;

        return $code->(@_);
    }

}


