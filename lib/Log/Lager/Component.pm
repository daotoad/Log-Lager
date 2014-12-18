package Log::Lager::Component;

use strict;
use warnings;

our %REGISTRY;

sub import {
    my ($class) = @_;
    my ($caller) = caller;

    $class->register( $caller );

    return;
}

sub register { shift; $REGISTRY{$_} = 1 for @_ }
sub is_registered { $REGISTRY{$_[1]//''} }

1;

__END__

=head1 NAME

Log::Lager::Component - Register a class as a part of Log::Lager

=head1 SYNOPSIS


    package Log::Lager::Some::AmazingThing

    use Log::Lager::Component;   # registers __PACKAGE__
    use Log::Lager::InlineClass;   # also registers  __PACKAGE__

    Log::Lager::Component->register( qw/  List::Of::Packages I::Want::To::Register /);

    Log::Lager::Component->registered('I::Want::To::Register'); # Returns 1 (true).
    Log::Lager::Component->registered('Never:Register'); a      # Returns undef


=head1 DESCRIPTION

In order to skip Log::Lager related modules, Log::Lager::Component implements a registry of related modules.
