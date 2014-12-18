package Log::Lager::InlineClass;

use strict;
use warnings;
use Log::Lager::Component;

sub import {
    my ($class) = caller;

    $INC{_incify( $class )} = "Inline - $0";
    Log::Lager::Component->register($class);

    return;
}

sub _incify {
    my ($class) = @_;

    $class =~ s#::#/#g;

    return "$class.pm";
}

1;

__END__

=head1 NAME

Log::Lager::InlineClass - Create multiple LL classes embedded in a single file. 

=head1 SYNOPSIS


    {   package Log::Lager::Message::MyMessage;
        use Log::Lager::InlineClass;
        use parent 'Log::Lager::Message';

        # Some code here
    }
    {   package Log::Lager::Tap::MyTap;
        use Log::Lager::InlineClass;
        use parent 'Log::Lager::Tap';

        # Some more code here
    }
 

=head1 DESCRIPTION

Log::Lager configuration loads Perl classes on demand.  
Log::Lager::InlineClass needs to be loaded in order to allow proper handling
of non-standard classes defined in another module or file.

