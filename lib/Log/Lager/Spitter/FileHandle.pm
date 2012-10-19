package Log::Lager::Spitter::FileHandle;
use strict;
use warnings;

our @ISA = 'Log::Lager::Spitter';

# Class Instance Attributes
my @Attrs;
BEGIN {
    require constant;
    @Attrs = qw<
        _file_handle
    >;
    for ( 0..$#Attrs ) {
        constant->import( $Attrs[ $_ ], $_ );
    }
}

sub new {
    my ( $class, %params ) = @_;
    return unless $class ne __PACKAGE__;

    my $self ||= bless( [], $class );
    $self->[_file_handle] = $params{ file_handle } || undef;
    return $self;
}

sub spit {
    my ( $self, $level, $message ) = @_;
    my $message_txt = $message->format() || "";
    $self->[_file_handle]->printflush( "$message_txt" );
    return;
}

1;
