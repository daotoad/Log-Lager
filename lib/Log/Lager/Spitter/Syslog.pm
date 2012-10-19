package Log::Lager::Spitter::Syslog;
use strict;
use warnings;

# perhaps we should factor these out of Lager.pm.
use constant SYSLOG_LEVELS => {
    F => 'LOG_CRIT',
    E => 'LOG_ERR',
    W => 'LOG_WARNING',
    I => 'LOG_INFO',
    D => 'LOG_DEBUG',
    T => 'LOG_DEBUG',
    G => 'LOG_DEBUG',
    U => 'LOG_DEBUG',
};
use constant DEFAULT_SYSLOG_LEVEL => 'LOG_ERR';

# Class attributes:
my @Attrs;
BEGIN {
    require constant;
    @Attrs = qw<
        _identity
        _facility
        _syslog_opened
    >;
    for ( 0..$#Attrs ) {
        constant->import( $Attrs[ $_ ], $_ );
    }
}

sub new {
    my ( $class, %params ) = @_;
    my $self = bless( [], $class );

    $self->[_identity]      = $params{ syslog_identity };
    $self->[_facility]      = $params{ syslog_facility };
    $self->[_syslog_opened] = 0;

    return $self->_open_sys_log()   # should we delay this until spit() is called?
        ? $self
        : undef;
}

sub _open_sys_log {
    my ( $self ) = @_;

    if( ! $self->[_syslog_opened] ) {
        eval {
            require Sys::Syslog;
            Sys::Syslog::openlog(
                $self->[_identity], 'ndelay,nofatal', $self->[_facility]
            );
            $self->[_syslog_opened] = 1;
            1;
        } or do {
            require Log::Lager;
            Log::Lager::ERROR( "Unable to open Syslog" );
        };
    }

    return $self->[_syslog_opened];
}

sub _get_syslog_level {
    my ( $level ) = @_;
    return SYSLOG_LEVELS->{ $level } || DEFAULT_SYSLOG_LEVEL;
}


sub spit {
    my ( $self, $level, $message ) = @_;
    my $message_txt = $message->format() || "";
    $self->_open_sys_log() unless( $self->[_syslog_opened] );
    my $syslog_level = _get_syslog_level( $level );
    Sys::Syslog::syslog( $syslog_level, "%s", $message_txt );
    return;
}

sub _DESTORY {
    my $self = shift;

    if( $self->[_syslog_opened] ) {
        require Sys::Syslog;
        Sys::Syslog::closelog();
        $self->[_syslog_opened] = 0;
    }

}

1;
