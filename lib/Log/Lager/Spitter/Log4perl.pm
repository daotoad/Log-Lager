package Log::Lager::Spitter::Log4perl;

#
# A Log Spitter
# ( i.e. follows the pattern of having an emit( $level, $message ) method )
# that interfaces with Log4perl, allowing users to configure log4perl but
# still use the Log::Lager interface
#

# TODO: add support for logdie() ( a log4perl method )

use strict;
use warnings;
use Carp qw< croak >;

use constant DEFAULT_LOG4PERL_METHOD => 'error';
use constant LOG4PERL_LEVEL_METHODS => {
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

sub _get_log4perl_method {
    my( $lager_level ) = @_;
    return LOG4PERL_LEVEL_METHODS->{ $lager_level } || DEFAULT_LOG4PERL_METHOD;
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
        my $method = _get_log4perl_method( $lager_level );
        $logger->$method( $message->message );
        1;
    } or do {
        require Log::Lager;
        Log::Lager::ERROR( "Failed to log to Log4perl: $@" );
    };
    return;
}

1;
