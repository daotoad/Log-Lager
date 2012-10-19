package Log::Lager::Spitter;
use strict;
use warnings;

# This method should go away with the new configuration file logic, since 
# config will tell us exactly which spitter to use and what to pass into it.
sub new_spitter {
    my ($class, %params) = @_;

    my $emitter;
    my $target = $params{ target };
    if( $target eq 'stderr' ) {
        require Log::Lager::Spitter::StdErr;
        $emitter = Log::Lager::Spitter::StdErr->new();
    }
    elsif( $target eq 'file' ) {
        require Log::Lager::Spitter::File;
        $emitter = Log::Lager::Spitter::File->new(
            filename => $params{ filename },
            fileperm => $params{ fileperm },
        );
    }
    elsif( $target eq 'syslog' ) {
        require Log::Lager::Spitter::Syslog;
        $emitter = Log::Lager::Spitter::Syslog->new(
            syslog_identity => $params{ syslog_identity },
            syslog_facility => $params{ syslog_facility },
        );
    }

    return $emitter;
}

sub default {
    my ( $class ) = @_;
    require Log::Lager::Spitter::StdErr;
    return Log::Lager::Spitter::StdErr->new();
}

1;
