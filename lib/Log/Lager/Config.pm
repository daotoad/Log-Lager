package Log::Lager::Config;

#use overload '""' => 'as_string';
use strict;
use warnings;

use Hash::Util qw< lock_keys >;

use Data::Dumper;

require Log::Lager;

sub new {
    my $class = shift;

    my $self = {
        file_path => '',
        load_time => 0,
        log_mask  => {
           base    => undef,
           'package' => {},
           'sub'     => {},
        },
        lexicals_enabled => undef,
        emitter => [ 'Log::Lager::Emitter::StdErr', {} ],
        message => [ 'Log::Lager::Message', {} ],
    };

    bless $self, $class;
    lock_keys %$self;

    return $self;
}

sub load_file {
    my $self = shift;
    my $path = shift || $self->{file_path};

    return unless $path;

    # Has config changed?
    if( $path eq $self->{file_path} ) {
        my $mtime = (stat $path)[9];
        return if $self->{load_time} > $mtime;
    }

    # Update file load time stamp.
    $self->{file_path} = $path;
    $self->{load_time} = time;

    # Try to load file
    my $raw_data;
    eval {
        if( $path =~ /.yaml$/ ) {
            require YAML;
            $raw_data = YAML::FileLoad( $path );
            _deboole_yaml( $raw_data->{disable_lexical_config})
                if defined $raw_data->{disable_lexical_config};
        }
        elsif( $path =~ /.json$/ ) {
            require JSON;
            open my $fh, '<', $path
                or die "could not open file: $!\n";
            $raw_data = JSON::decode_json( join '', <$fh> );
            _deboole_json( $raw_data->{disable_lexical_config})
                if defined $raw_data->{disable_lexical_config};
        }
        1;
    }
    or do {
        warn "Error opening config file '$path': $@\n";
        Log::Lager::ERROR( "Error opening config file", $path, $@ );
        return;
    };

    # Load data into object;
    $self->from_data( $raw_data );
}


sub _deboole_yaml { $_[0] = $_[0] =~ /^\s*(y(es)|t(rue))\s*$/i ? 1 : 0; }
sub _boolify_yaml { $_[0] = $_[0] ? 'TRUE' : 'FALSE'; }

sub _deboole_json { $_[0] += 0; }
sub _boolify_json { $_[0] = $_[0] ? JSON::true() : JSON::false(); }

sub from_data {
    my $self = shift;
    my $raw = shift;

    warn Dumper $raw;
#use Hash::Util qw<lock_hash>;
#    lock_hash %$raw;

    $self->set_mask( base => undef => $raw->{base_mask} );
    $self->set_mask( package => $_ => $raw->{package_masks}{$_} )
        for keys %{ $raw->{package_masks} || {} };
    $self->set_mask( 'sub' => $_ => $raw->{subroutine_masks}{$_} )
        for keys %{ $raw->{subroutine_masks} || {} };

    $self->{lexicals_enabled} = ! $raw->{disable_lexical_config};
    $self->set_emitter($raw->{emitter_type}, $raw->{emitter_options});
    $self->set_message($raw->{message_type}, $raw->{message_options});

    return $self;
}

sub set_mask {
    my ( $self, $type, $pkg, $maskstring ) = @_;

    return unless exists $self->{log_mask}{$type};

    if( defined $maskstring ) {
        if( $type eq 'base' ) {
            $self->{log_mask}{$type} = $maskstring;
        }
        else {
            $self->{log_mask}{$type}{$pkg} = $maskstring;
        }
    }
    else {
        delete $self->{log_mask}{$type}{$pkg};
    }

    return 1;
}

sub get_mask {
    my $self =shift;
    my $type = shift;

    return Log::Lager::Mask->parse_command($self->{log_mask}{base})
        if( $type eq 'base' );

    my $name = shift;

    return unless exists $self->{log_mask}{$type};
    return unless exists $self->{log_mask}{$type}{$name};

    return Log::Lager::Mask->parse_command($self->{log_mask}{$type}{$name});
}

sub package_names {
    my $self = shift;

    return sort keys %{$self->{log_mask}{package}};
}

sub sub_names {
    my $self = shift;

    return sort keys %{$self->{log_mask}{sub}};
}

sub set_emitter {
    my $self = shift;
    my $type = shift;
    my $options = shift || {};

    eval "require $type; 1"
        or do {
            warn "Invalid emitter class - $type - $@";
            Log::Lager::ERROR( "Invalid emitter class", $type, $@);
            return;
        };

    $self->{emitter}=[$type, $options];
    return 1;
}

sub get_emitter {
    my $self = shift;
    my $old  = shift;

    my $type = $self->{emitter}[0];
    my $options = $self->{emitter}[1];

    return $old
        if (    defined $old
            and $old->isa($type)
            and $old->config_matches($options)
        );

    return $type->new( %$options );
}

sub set_message {
    my $self    = shift;
    my $type    = shift;
    my $options = shift || {};

    eval "require $type; 1"
        or do {
            warn "Invalid message class - $type - $@";
            Log::Lager::ERROR( "Invalid message class", $type, $@);
            return;
        };

    $self->{message}=[$type, $options];
    return 1;
}

sub get_message_settings {
    my $self    = shift;

    return @{ $self->{message} || [] };
}

sub file_type {
    my $self = shift;

    return 'DATA' unless $self->{file_path};
    return 'YAML' if $self->{file_path} =~ /\.yaml$/;
    return 'JSON' if $self->{file_path} =~ /\.json$/;
    return;
}

sub lexicals_enabled {
    my $self = shift;

    return !!$self->{lexicals_enabled};
}

sub as_string {
    my $self = shift;

    my $type = $self->file_type();

    my $cfg_data = {
        disable_lexical_config => !$self->{lexicals_enabled},
        base_mask        => $self->{masks}{base},
        package_masks    => $self->{masks}{package},
        subroutine_masks => $self->{masks}{sub},
        message_type     => $self->{message}[0],
        message_options  => $self->{message}[1],
        emitter_type     => $self->{emitter}[0],
        emitter_options  => $self->{emitter}[1],
    };

    eval {
        if( $type eq 'YAML' ) {
            require YAML;
            _boolify_yaml( $cfg_data->{disable_lexical_config} );
            return YAML::Dump( $cfg_data );

        }
        else {  #  $type eq 'JSON'
            require JSON;
            _boolify_json( $cfg_data->{disable_lexical_config} );
            return JSON::encode_json( $cfg_data );
        }
    }
    or do {
        warn "Error converting configuration to $type string";
        Log::Lager::ERROR( "Error converting configuration to $type string");
    };
    return;
}


1;
