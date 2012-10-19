package Log::Lager::Spitter::StdOut;
use strict;
use warnings;

my $singleton;

sub new {
    my ( $class ) = @_;
    $singleton ||= bless( [], $class );
    return $singleton;
}

sub spit {
    my ( $self, $level, $message ) = @_;
    my $message_txt = $message->format() || "";
    STDOUT->printflush( "$message_txt" );
    return;
}

1;
