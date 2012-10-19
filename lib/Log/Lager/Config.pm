package Log::Lager::Config;

use overload '""' => 'as_string';
use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {
        file_path => '',
        load_time => 0,
        log_mask  => {
           base    => undef,
           package => {},
           sub     => {},
        },
        lexicals_enabled => undef,
        emitter => [ 'Log::Lager::Emitter::Stderr', {} ],
        message => [ 'Log::Lager::Message', {} ],
    };

    bless $self, $class;

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
            $raw_data->{disable_lexical_config} += 0
                if defined $raw_data->{disable_lexical_config};
        }
        1;
    }
    or do {
        warn "Error opening config file '$path': $@\n";
        ERROR( "Error opening config file", $path, $@ );
        return;
    };

    # Load data into object;
    $self->_init( $raw_data );
}

sub _deboole_yaml { $_[0] = $_[0] =~ /^\s*(y(es)|t(rue))\s*$/i ? 1 : 0; }
sub _boolify_yaml { $_[0] = $_[0] : 'TRUE' ? 'FALSE'; }

sub _deboole_json { $_[0] += 0; }
sub _boolify_json { $_[0] = $_[0] : JSON::true ? JSON::false; }

sub _init {
    my $self = shift;
    my $raw = shift || {
        base_mask        => $Log::Lager::DEFAULT_BASE,
        package_masks    => undef,
        subroutine_masks => undef,
        disable_lexical_config => 0,
        emitter => [ 'Log::Lager::Emitter::StdOut' ],
        message => [ 'Log::Lager::Message' ],
    };

    $self->set_mask( base => undef => $raw->{base_mask} );
    $self->set_mask( package => $_ => $raw->{package_masks}{$_} )
        for keys %{ $raw->{package_masks} || {} };
    $self->set_mask( 'sub' => $_ => $raw->{subroutine_masks}{$_} )
        for keys %{ $raw->{subroutine_masks} || {} };

    $self->{lexicals_enabled} = ! $raw->{disable_lexical_config};
    $self->set_emitter($raw->{emitter});
    $self->set_message($raw->{message});
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

sub file_type {
    my $self = shift;

    return 'YAML' if $self->{file_path} =~ /\.yaml$/;
    return 'JSON' if $self->{file_path} =~ /\.json$/;
    return;
}

sub as_string {
    my $self = shift;

    my $type = $self->filetype();

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
        if( $type eq 'YAML' {
            require YAML;
            _boolify_yaml( $cfg_data->{disable_lexical_config} );
            return YAML::Dump( $data );

        }
        else {  #  $type eq 'JSON'
            require JSON;
            _boolify_json( $cfg_data->{disable_lexical_config} );
            return JSON::encode_json( $data );
        }
    }
    or do {
        warn "Error converting configuration to $type string";
        ERROR "Error converting configuration to $type string";
    };
    return;
}


1;
