package Log::Lager::Spitter::Log4perl;

#
# A Log Spitter that allows users to use Log::Lager as a proxy interface
# to Log4perl
#

# TODO: add support for logdie() ( a log4perl method )
# TODO: add support for specifying log4perl config

use strict;
use warnings;
use Carp qw< croak >;

use constant DEFAULT_LOG4PERL_METHOD => 'error';
use constant LOG4PERL_LEVEL_METHODS  =>
{
    F => 'fatal',
    E => 'error',
    W => 'warn',
    I => 'info',
    D => 'debug',
    T => 'trace',
    G => DEFAULT_LOG4PERL_METHOD,
    U => DEFAULT_LOG4PERL_METHOD,
};

# Class attributes:
my @Attrs;
BEGIN {
    require constant;
    @Attrs = qw<
        _category
    >;
    for ( 0..$#Attrs ) {
        constant->import( $Attrs[ $_ ], $_ );
    }
}

sub new {
    my( $class, %params ) = @_;
    my $self = bless( [], $class );
    $self->[_category] = $params{ category } || undef;
    return $self;
}

sub _get_method_for_level {
    my( $lager_level ) = @_;
    return LOG4PERL_LEVEL_METHODS->{ $lager_level }
        || DEFAULT_LOG4PERL_METHOD;
}

sub spit {
    my( $self, $lager_level, $message ) = @_;
    croak "Must provide Log::Lager::Message instance"
        unless( 'Log::Lager::Message' eq ref( $message ) );

    eval {
        require Log::Log4perl;
        my $logger =
            $self->[_category]
                ? Log::Log4perl->get_logger( $self->[_category] )
                : Log::Log4perl->get_logger();

        my $level_method = _get_method_for_level( $lager_level );
        for my $message_unit ( @{ $message->message } ) {
            $logger->$level_method( $message_unit );
        }
        1;
    } or do {
        require Log::Lager;
        Log::Lager::ERROR( "Failed to log to Log4perl: $@" );
    };

    return;
}

1;
