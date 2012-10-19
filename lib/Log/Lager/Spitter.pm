package Log::Lager::Spitter;
use strict;
use warnings;

# A base class for all Spitter classes

# TODO Add support for nested options in config_matches( ) (only support flat hashes right now)

sub new {
    my ( $class, %params ) = @_;
}

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

sub default {   # returns the default spitter
    my ( $class ) = @_;
    require Log::Lager::Spitter::StdErr;
    return Log::Lager::Spitter::StdErr->new();
}

sub _get_identity_options {
    my ( $self ) = @_;
    my $class = ref( $self );
    no strict 'refs';
    return ${ "${class}::IDENTITY_OPTIONS" } || [];
}

sub _get_attribute_for_option {
    my ( $self, $option_name ) = @_;
    my $class = ref( $self );
    no strict 'refs';
    my $map = ${ "${class}::OPTION_ATTRIBUTE_INDEX_MAP" } || {};
    my $attr_index = $map->{ $option_name };
    my $attr_val = $self->[ $attr_index ];
    return $attr_val;
}

sub config_matches {
    my $self    = shift;    # a subclass, in most cases
    my $options = shift;

    for my $identity_option ( @{ $self->_get_identity_options() } ) {
        my $attr_val = $self->_get_attribute_for_option( $identity_option );

        if( $attr_val ne $options->{ $_ } ) {
            return 0;
        }
    }
    return 1;
}

1;
