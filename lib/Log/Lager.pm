package Log::Lager;

use Data::Dumper;

use strict;
use warnings;
use Carp qw( croak );
$Carp::Internal{'Log::Lager'}++;
use Scalar::Util qw(reftype);
use JSON::XS;
use IO::Handle;

use Log::Lager::Mask;
use Log::Lager::Message;
use Log::Lager::Tap::STDERR;

*INTERNAL_TRACE = sub () { 0 }
    unless defined &INTERNAL_TRACE;

# Global configuration
# === Global mask variables ===
# These global masks are controlled as a side effect of _parse_commands();
our $BASE_MASK = 0;          # Base mask that all other masks are calculated relative to
our %PACKAGE_MASK;       # Storage for package specific masks
our %SUBROUTINE_MASK;    # Storage for sub specific masks

# === Global config ===
our $CONFIG_SOURCE;
# Non-mask variables that store current configuration information
our $ENABLE_LEXICAL;     # Boolean flag for lexical controls
our $TAP_CLASS;          # Output tap 
our $TAP_CONFIG;         # Output tap configuration 
our $TAP_OBJECT;         # Output tap object instance 

our $OUTPUT_FUNCTION;    # Code ref of emitter function.

our $PREVIOUS_CONFIG_FILE = '';
our $CONFIG_LOAD_TIME     = 0;
our $MESSAGE_CLASS;
our $MESSAGE_CONFIG = {};

our $DEFAULT_CONFIG = {
    lexical_control => 1,
    levels => {
        base => ' enable  FEW      disable TDIGU'
              . ' compact FEWTDIGU pretty '
              . ' fatal   F        nonfatal EWTDIGU'
              . ' stack            nostack  FEWTDIGU',
        package => {},
        sub => {},
    },
    message => { 'Log::Lager::Message' => {} },
    tap     => { STDERR => {} },
};

# === Configure Log Levels ===
use constant {      # Indexes of the various elements in the LOG_LEVELS ARRAY
    MASK_CHAR    => 0,
    FUNCTION     => 1,
    BITFLAG      => 2,
    SYSLOG_LEVEL => 3,
};
my @LOG_LEVELS = (
    [ F => FATAL => 0x01, 'LOG_CRIT'    ],
    [ E => ERROR => 0x02, 'LOG_ERR'     ],
    [ W => WARN  => 0x04, 'LOG_WARNING' ],
    [ I => INFO  => 0x08, 'LOG_INFO'    ],
    [ D => DEBUG => 0x10, 'LOG_DEBUG'   ],
    [ T => TRACE => 0x20, 'LOG_DEBUG'   ],
    [ G => GUTS  => 0x40, 'LOG_DEBUG'   ],
    [ U => UGLY  => 0x80, 'LOG_DEBUG'   ],
);

use constant {  # Number of bits to left shift for access to different parts of config mask.
    ENABLE_BITSHIFT   => 0,
    FATALITY_BITSHIFT => 8,
    PRETTY_BITSHIFT   => 16,
    STACK_BITSHIFT    => 24,
};

# Process @LOG_LEVELS for easy access
my %LOG_LEVEL_BY_FUNC = map { $_->[FUNCTION] => $_ }  @LOG_LEVELS;
my @MASK_CHARS = map $_->[MASK_CHAR], @LOG_LEVELS;
our %MASK_CHARS; @MASK_CHARS{@MASK_CHARS} = @LOG_LEVELS;
my $MASK_REGEX = join '', keys %MASK_CHARS;

# === Initialize masks  ===
Log::Lager->set_config( $DEFAULT_CONFIG );

# === Message output ===
# Log Level functions
sub FATAL { _handle_message( F => @_ ) }
sub ERROR { _handle_message( E => @_ ) }
sub WARN  { _handle_message( W => @_ ) }
sub INFO  { _handle_message( I => @_ ) }
sub DEBUG { _handle_message( D => @_ ) }
sub TRACE { _handle_message( T => @_ ) }
sub GUTS  { _handle_message( G => @_ ) }
sub UGLY  { _handle_message( U => @_ ) }

# This function provides the meat of the logic behind the log level functions.
sub _handle_message {
    my $level = shift;

    croak "Invalid log level '$level'"
        unless exists $MASK_CHARS{$level};

    my ($on_bit, $die_bit, $pretty_bit, $stack_bit ) =_get_bits(2, $MASK_CHARS{$level}[BITFLAG]);

    # Get raw messages from either callback or @_
    my @messages;
    {   no warnings 'uninitialized';

        if( @_ == 1
            && reftype($_[0]) eq 'CODE'
        ) {
            return if !$on_bit;
            @messages = $_[0]->();
        }
        else {
            @messages = @_;
        }
    }

    my $msg;
    my @return_values;
    my $return_exception;
    # Is @messages a single entry of type Log::Lager::Message?
    if( eval {
        @messages == 1
        && $messages[0]->isa('Log::Lager::Message')
    }) {

        if( Log::Lager::INTERNAL_TRACE() ) {
            STDERR->printflush( "Processing custom message object\n" );
            use Data::Dumper; STDERR->printflush( Dumper \@messages );
        }

        $msg = $messages[0];
        $msg->loglevel( $MASK_CHARS{$level}[FUNCTION] )
            unless $msg->loglevel;
        $msg->expanded_format($pretty_bit)
            unless defined $msg->expanded_format;

        my $obj_want_stack = $msg->want_stack;
        $obj_want_stack = $stack_bit
            unless defined $obj_want_stack;

        $msg->callstack( $msg->_callstack )
            if (
                    $obj_want_stack
            and not $msg->callstack
            );

        my $rv = $msg->return_values;
        @return_values = @$rv if ref($rv) eq 'ARRAY';
        $return_exception = $msg->return_exception;

        if( Log::Lager::INTERNAL_TRACE() ) {
            STDERR->printflush( "Finished processing custom message object\n" );
            use Data::Dumper; STDERR->printflush( Dumper $msg );
        }


    }
    else {
        return if !$on_bit;
        $msg = $MESSAGE_CLASS->new(
            %$MESSAGE_CONFIG,
            context         => 0,
            loglevel        => $MASK_CHARS{$level}[FUNCTION],
            message         => \@messages,
            want_stack      => $stack_bit,
            expanded_format => $pretty_bit,
        );
    }

    if ($on_bit) {
        my $emitter = $OUTPUT_FUNCTION ? $OUTPUT_FUNCTION : Log::Lager::Tap::STDERR->new()->gen_output_function();

        $emitter->($level, $die_bit, $msg);

        load_config();
    }

    die $return_exception    if defined $return_exception;
    return                   if !defined wantarray;
    return @return_values    if wantarray;
    return $return_values[0] if @return_values <= 1;
    die "Have multiple return values when wantarray is false\n";
}


# == Bitmask manipulation ==

sub _bitmask_to_mask_string {
    my $bitmask = shift;
    my $shift   = shift;

    return '' unless defined $bitmask;

    # Get string of true bits
    my $string = join '',
                 map  $_->[MASK_CHAR],
                 grep $bitmask & ($_->[BITFLAG] << $shift),
                 @LOG_LEVELS;

    return $string;
}

# table lookup
# May be faster -
# Requires strings to be normalized
# Current method handles repeats, out of order correctly.
sub _mask_string_to_bitmask {
    my $string = shift;

    return 0 unless defined $string;

    my $mask = 0;
    for my $c ( split //, $string ) {
        $mask |= $MASK_CHARS{$c}->[BITFLAG];
    }

    return $mask;
}

# speedup by moving for data out of sub/to state var
sub _convert_mask_to_bits {
    my $mask = shift;

    my ($on, $off) = (0,0);

    for (
        [ ENABLE_BITSHIFT,   'enable', 'disable'  ],
        [ FATALITY_BITSHIFT, 'fatal',  'nonfatal' ],
        [ PRETTY_BITSHIFT,   'pretty', 'compact'  ],
        [ STACK_BITSHIFT,    'stack',  'nostack'  ],
    ) {
        my ( $shift, $on_method, $off_method ) = @$_;

        my $on_bits  = _mask_string_to_bitmask($mask->get_mask($on_method));
        my $off_bits = _mask_string_to_bitmask($mask->get_mask($off_method));
        $on  |= $on_bits  << $shift;
        $off |= $off_bits << $shift;
    }

    return ($on, $off);
}

sub _apply_bits_to_mask {
    my ($on_bits, $off_bits, $mask ) = @_;

    for ( [enable => disable => ENABLE_BITSHIFT],
          [stack  => nostack => STACK_BITSHIFT],
          [pretty => compact => PRETTY_BITSHIFT],
          [fatal  => nonfatal => FATALITY_BITSHIFT]
      ) {
        my ( $on, $off, $shift) = @$_;

        $mask->set_mask( $on,  _bitmask_to_mask_string( $on_bits, $shift  ));
        $mask->set_mask( $off, _bitmask_to_mask_string( $off_bits, $shift ));
    }

    return;
}

sub _get_bits {
    my $frame = shift;
    my $flag = shift;

    my $on_bit     = $flag << ENABLE_BITSHIFT;
    my $die_bit    = $flag << FATALITY_BITSHIFT;
    my $pretty_bit = $flag << PRETTY_BITSHIFT;
    my $stack_bit  = $flag << STACK_BITSHIFT;

    my ($package, $sub, $hints) = (caller($frame))[0,3,10];

    my $s_mask = exists $SUBROUTINE_MASK{$sub}  ? $SUBROUTINE_MASK{$sub}  : [0,0];
    my $p_mask = exists $PACKAGE_MASK{$package} ? $PACKAGE_MASK{$package} : [0,0];
    my $l_mask = $ENABLE_LEXICAL
               ? [$hints->{'Log::Lager::Log_enable'},
                  $hints->{'Log::Lager::Log_disable'}]
               : [0,0];

    my $mask = defined $BASE_MASK ? $BASE_MASK : 0;

    for my $apply ( $l_mask, $p_mask, $s_mask,  ) {
        $mask |=   defined $apply->[0] ? $apply->[0] : 0;
        $mask &= ~(defined $apply->[1] ? $apply->[1] : 0);
    }

    $on_bit     = $on_bit     & $mask ? 1 : 0;
    $die_bit    = $die_bit    & $mask ? 1 : 0;
    $stack_bit  = $stack_bit  & $mask ? 1 : 0;
    $pretty_bit = $pretty_bit & $mask ? 1 : 0;

    return $on_bit, $die_bit, $pretty_bit, $stack_bit;
}


# == Module loaders ==

sub _load_lager_class {
    my ( $class, $hierarchy ) = @_;

    $class =~ /^\w+(::\w+)*$/
        or die "Invalid class name $class";

    my $short_class = "${hierarchy}::$class"
        if defined $hierarchy;

    my $got_class;
    eval "use $class; \$got_class='$class'; 1"
    or eval "use Log::Lager::$short_class; \$got_class = 'Log::Lager::$short_class'; 1"
    or croak "Unable to load class $class";

    return $got_class;
}

sub _load_message_class {
    my ( $message_config ) = @_;

    my ($class, $config) = %$message_config;

    $class = _load_lager_class($class, 'Message');

    # TODO Validate config here.
    
    return $class;
}

sub _load_tap_class {
    my ( $tap_config ) = @_;

    my ($class, $config) = %$tap_config;

    $class = _load_lager_class($class, 'Tap');

    # TODO Validate config here.
    my $obj = $class->new(%$config);
    
    return $class;
}

sub _load_config_class {
    my ( $config_source ) = @_;

    my ($class, $config) = %$config_source;

    $class = _load_lager_class($class, 'Config');

    # TODO Validate config here.
    my $obj = $class->new(%$config);
    
    return $class;
}

# == == 

sub _parse_log_level {
    my ($ll, $bitmask) = @_;
    my $group  = $Log::Lager::Mask::GROUP_REGEX;
    my $levels = "[$MASK_REGEX]*";

    $ll = join ' ', @$ll if ref $ll;
    
    $ll =~ /^\s*(|($group)(\s+$levels)*)(\s+($group)(\s+$levels)*)*\s*$/
        or croak "Invalid log level: $ll";

    my $mask = Log::Lager::Mask->new();
    $mask->apply_string($ll);

    my @bitmask = _convert_mask_to_bits( $mask, @$bitmask );

    return \@bitmask;
}

# Non-standard import method.
# Parse a log configuration command.
# May also import log emitter functions if not already present.
#
# Injects a "lexical enable" at start of command
sub import {
    shift;
    my ($import, $cfg, @levels);
    for(@_) {
        my $type = ref $_;
        if( 'HASH' eq $type ) {
            $cfg = $_;
            if ( $cfg->{config} ) {
                Log::Lager->load_config( $cfg->{config} );
            }
            else {
                Log::Lager->set_config( $cfg );
            }
        }
        elsif( 'ARRAY' eq $type ) {
            croak "Only a single import array may be specified"
                if $import;
            $import = $_;
        }
        else {
            push @levels, $_;
        }
    }

    my $caller = caller;

    # Import functions
    # Skip if this is not the first time through
    my $hints = (caller(1))[10];
    unless( defined $hints->{'Log::Lager::Log_enable'} ) {
        no strict 'refs';
        my @import = $import
                   ? (@$import)
                   : (map $_->[FUNCTION], @LOG_LEVELS);

        for my $i ( @import ) {
            my ($func, $import_as) = (ref $i ? (@$i) : ($i,$i));

            my $dest_func = "${caller}::$import_as";
            *$dest_func = \&$func;
        }
    }

    set_lexical_log_level( [ 'enable', @levels], 1 );

    return;
}

# Non-standard unimport
# Allows for restricted command set.
# Used to disable log levels in a particular lexical scope.

sub unimport {
    shift;
    my @commands = @_;

    croak "Use 'Log::Lager' with log level codes only"
        if grep /[^$MASK_REGEX]/, @commands;

    set_lexical_log_level( [ 'disable', @_], 1 );

    return;
}

# Emit the current logging settings as a string usable as a configuration
# command.
sub log_level {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };

    my $r;

    # Base
    $r->{base} = Log::Lager::Mask->new();
    _apply_bits_to_mask( $BASE_MASK, ~$BASE_MASK, $r->{base} );

    # Lexical
    my $hints = (caller(0))[10];
    $r->{lexical} = Log::Lager::Mask->new();
    _apply_bits_to_mask(
        $hints->{'Log::Lager::Log_enable'},
        $hints->{'Log::Lager::Log_disable'},
        $r->{lexical}
    );

    # Package
    _apply_bits_to_mask(
            @{$PACKAGE_MASK{$_}||[0,0]},
            $r->{package}{$_} = Log::Lager::Mask->new()
        ) for keys %PACKAGE_MASK;

    # Sub
    _apply_bits_to_mask( @{$SUBROUTINE_MASK{$_}||[0,0]}, 
            $r->{sub}{$_} = Log::Lager::Mask->new()
        ) for keys %SUBROUTINE_MASK;

    return $r;
}


# Accessorize configuration
sub configure_lexical_control {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };
    my ( $enable ) = @_;

    $ENABLE_LEXICAL = $enable ? 1 : 0;

    return;
}

sub configure_default_message {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };
    my ( $class, $config ) = @_;

    $class = _load_message_class( {$class, $config} );

    $MESSAGE_CLASS  = $class;
    $MESSAGE_CONFIG = { %$config };

    return;
}

sub configure_tap {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };
    my ( $class, $config ) = @_;

    $TAP_OBJECT->deselect() if $TAP_OBJECT;

    $class = _load_tap_class( {$class, $config} );

    $TAP_CLASS  = $class;
    $TAP_CONFIG = { %$config };
    $TAP_OBJECT = $TAP_CLASS->new( %$TAP_CONFIG )
        or die "Error creating Tap object.\n";
    $TAP_OBJECT->select();

    $OUTPUT_FUNCTION = $TAP_OBJECT->gen_output_function();

    return;
}

sub configure_base_log_level {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };
    my ($level) = @_;
    my $mask = _parse_log_level( $level );
    $BASE_MASK = $mask->[0] & ~ $mask->[1];

    return;
}

sub configure_package_log_level {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };
    my ($package, $level) = @_;

    if ( defined $level and length $level ) {
        $level = _parse_log_level( $level );
        $PACKAGE_MASK{$package}=$level;
    }
    else {
        delete $PACKAGE_MASK{$package};
    }

    return;
}

sub configure_sub_log_level {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };
    my ($sub, $level) = @_;

    if ( defined $level and length $level ) {
        $level = _parse_log_level( $level );
        $SUBROUTINE_MASK{$sub}=$level;
    }
    else {
        delete $SUBROUTINE_MASK{$sub};
    }

    return;
}


sub _configure {
    &_PKGCALL;
    my %config = @_;

    my %cfg = (
        lex  => $ENABLE_LEXICAL,
        base => $BASE_MASK,
        subs => { %SUBROUTINE_MASK },
        pkg  => { %PACKAGE_MASK },
        msg_class  => $MESSAGE_CLASS,
        msg_config => $MESSAGE_CONFIG,
        tap_class  => $TAP_CLASS,
        tap_config => $TAP_CONFIG,
        tap_object => $TAP_OBJECT,
        output_func => $OUTPUT_FUNCTION,
    );


    eval {

        local $ENABLE_LEXICAL;
        local $BASE_MASK;
        local %SUBROUTINE_MASK;
        local %PACKAGE_MASK;
        local $MESSAGE_CLASS;
        local $MESSAGE_CONFIG;
        local $TAP_CLASS;
        local $TAP_CONFIG;
        local $TAP_OBJECT = $TAP_OBJECT;

        configure_lexical_control( $config{lexical_control} );
        configure_base_log_level( $config{levels}{base} );
        configure_sub_log_level( $_, $config{levels}{sub}{$_} )
            for keys %{$config{levels}{sub}};
        configure_package_log_level( $_, $config{levels}{package}{$_} )
            for keys %{$config{levels}{package}};
        configure_default_message( %{$config{message} } ); 
        configure_tap( %{$config{tap} } ); 

        $cfg{lex}         = $ENABLE_LEXICAL;
        $cfg{base}        = $BASE_MASK;
        $cfg{subs}        = \%SUBROUTINE_MASK;
        $cfg{pkg}         = \%PACKAGE_MASK;
        $cfg{msg_class}   = $MESSAGE_CLASS;
        $cfg{msg_config}  = $MESSAGE_CONFIG || {};
        $cfg{tap_class}   = $TAP_CLASS;
        $cfg{tap_config}  = $TAP_CONFIG || {};
        $cfg{tap_object}  = $TAP_OBJECT;
        $cfg{output_func} = $OUTPUT_FUNCTION;

        1;
    } or die;

    $ENABLE_LEXICAL     = $cfg{lex};
    $BASE_MASK          = $cfg{base};
    %SUBROUTINE_MASK    = %{$cfg{subs}};
    %PACKAGE_MASK       = %{$cfg{pkg}};
    $MESSAGE_CLASS      = $cfg{msg_class}  || 'Log::Lager::Message';
    $MESSAGE_CONFIG     = $cfg{msg_config} || {};
    $TAP_CLASS          = $cfg{tap_class}  || 'Log::Lager::Tap::STDERR';
    $TAP_CONFIG         = $cfg{tap_config} || {};
    $TAP_OBJECT         = $cfg{tap_object};
    $OUTPUT_FUNCTION    = $cfg{output_func};

    return;
}

sub _PKGCALL {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };
}

# Experimental idea
#   translate object attributes to localized globals on the fly.
#   allows multiple objects with different settings
#   adds a good hunk of overhead to each call.
#
# my $ll = Log::Lager->new();
# $ll->OOPY( FATAL => 'I ate cheese' );
# $ll->OOPY( load_config_file => 'some_file' );
sub OOPY {
    my ($self, $method, @args) = @_;
    my $wantarray = wantarray();

    my %orig = (
        enable_lexical => \$ENABLE_LEXICAL,
        base_mask      => \$BASE_MASK,
        sub_masks      => \%SUBROUTINE_MASK,
        package_masks  => \%PACKAGE_MASK,
        message_class  => \$MESSAGE_CLASS,
        message_config => \$MESSAGE_CONFIG,
        tap_class      => \$TAP_CLASS,
        tap_config     => \$TAP_CONFIG,
        tap_object     => \$TAP_OBJECT,
    );

    my ($result, @result);
    eval {
        local $ENABLE_LEXICAL  = $self->{enable_lexical};
        local $BASE_MASK       = $self->{base_mask};
        local %SUBROUTINE_MASK = %{$self->{sub_masks}};
        local %PACKAGE_MASK    = %{$self->{package_masks}};
        local $MESSAGE_CLASS   = $self->{message_class};
        local $MESSAGE_CONFIG  = $self->{message_config};
        local $TAP_CLASS       = $self->{tap_class};
        local $TAP_CONFIG      = $self->{tap_config};
        local $TAP_OBJECT      = $self->{tap_object};


        if( $wantarray ) {
            @result = $self->$method(@args);
        }
        else {
            $result = $self->$method(@args);
        }

        $self->{enable_lexical}   = $ENABLE_LEXICAL;
        $self->{base_mask}        = $BASE_MASK;
        %{$self->{sub_masks}}     = %SUBROUTINE_MASK;
        %{$self->{package_masks}} = %PACKAGE_MASK;
        $self->{message_class}    = $MESSAGE_CLASS;
        $self->{message_config}   = $MESSAGE_CONFIG || {};
        $self->{tap_class}        = $TAP_CLASS;
        $self->{tap_config}       = $TAP_CONFIG || {};
        $self->{tap_object}       = $TAP_OBJECT;
    } or die;

    return $wantarray ? @result : $result;
}
# ---------------- NEW INTERFACE BELOW THIS LINE ----------------


# take passed in log level string(s) and sets lexical level
sub set_lexical_log_level {
    &_PKGCALL;
    my ( $log_levels, $caller_level ) = 
        ref $_[0] ? ( $_[0], $_[1] )
                  : ( [@_] );

    $DB::single=1;
    return unless @$log_levels;

    $caller_level += 1;   

    my $hints = (caller($caller_level))[10];

    # Apply log level mask
    my $mask = [
        $^H{'Log::Lager::Log_enable'},
        $^H{'Log::Lager::Log_disable'}
    ];
    $mask = _parse_log_level( $log_levels, $mask );

    $^H{'Log::Lager::Log_enable'}  = defined($mask->[0]) ? $mask->[0] : 0;
    $^H{'Log::Lager::Log_disable'} = defined($mask->[1]) ? $mask->[1] : 0;

    return;
}


# Return current effective log level.
# TODO let this take a level.
sub get_log_level { # TODO move log_level 
    &_PKGCALL;

    my $mask = Log::Lager::Mask->new();
    # Base
    _apply_bits_to_mask( $BASE_MASK, ~$BASE_MASK, $mask );

    # Lexical
    my ($package, $sub, $hints) = (caller(1))[0,3,10];
    _apply_bits_to_mask(
        $hints->{'Log::Lager::Log_enable'},
        $hints->{'Log::Lager::Log_disable'},
        $mask
    );

    # Package
    _apply_bits_to_mask( @{$PACKAGE_MASK{$package}||[0,0]}, $mask );

    # Sub
    _apply_bits_to_mask( @{$SUBROUTINE_MASK{$sub}||[0,0]}, $mask );

    return $mask->as_string;
}

sub set_config {
    &_PKGCALL;
    my ($cfg) = @_;
    _configure( %$DEFAULT_CONFIG, %$cfg );
    return;
}
sub get_config {
    &_PKGCALL;

    my %cfg = (
        lexical_control => 0,
        tap     => {},
        message => {},
        levels => {
            base    => undef,
            package => {},
            sub     => {},
        },
    );
    $cfg{lexical_control} = $ENABLE_LEXICAL;

    my $mask = Log::Lager::Mask->new();
    _apply_bits_to_mask( $BASE_MASK, ~$BASE_MASK, $mask );
    $cfg{levels}{base} = "$mask";

    for (keys %PACKAGE_MASK) {
        my $mask = Log::Lager::Mask->new();
        _apply_bits_to_mask( @{$PACKAGE_MASK{$_}}, $mask );
        $cfg{levels}{package}{$_} = "$mask";
    }

    for (keys %SUBROUTINE_MASK) {
        my $mask = Log::Lager::Mask->new();
        _apply_bits_to_mask( @{$SUBROUTINE_MASK{$_}}, $mask );
        $cfg{levels}{sub}{$_} = "$mask";
    }

    $cfg{message}{$MESSAGE_CLASS} = {%$MESSAGE_CONFIG};
    $cfg{tap}{$TAP_CLASS} = {%$TAP_CONFIG};

    return \%cfg;
}

sub load_config {
    &_PKGCALL;
    my ($source) = @_;

    my ($this_source, $last_source);
    if ($source) {
        my ($class, $opts) = %$source;
        $class = _load_config_class($source);
        $this_source = $class->new(%$opts);
        $last_source = $CONFIG_SOURCE;
        $CONFIG_SOURCE = $this_source;
    }
    else {
        $this_source = $CONFIG_SOURCE;
    }

    return if !$this_source;

    my $cfg = $this_source->load( $last_source );
    set_config( $cfg );

}


1;



__END__


=for Pod::Coverage

import

=for Pod::Coverage

unimport


=head1 NAME

Log::Lager - Easy to use, flexible, parsable logs.

=head1 SYNOPSIS

This modules provides serveral key features:

* orthogonal configuration of all log levels,
* lexical log level configuration,
* runtime logging controls
* JSON log entries with built in data dumping and support for self-referential data.


The goal is to provide an easy to use logging facility that meets developer
and production needs.

    # Enable standard logging levels: FATAL ERROR WARN. With FATAL being fatal.
    use Log::Lager;

    INFO('I is off');  # Nothing happens, INFO is OFF

    use Log::Lager nonfatal => 'F', enable => 'I';  # FATAL events are no longer fatal.

    FATAL('Still kicking');
    INFO('I is ON');  # Log an entry.

    {   no Log::Lager 'I';   # Disable INFO

        INFO('Info is OFF'); # If run with lexoff, this will log.
    }
    INFO('Working again');  # INFO is back on

    # Make FATAL fatal again.
    use Log::Lager fatal => 'F';
    FATAL('Oh noes');  # Log an error and throw an exception.


    # Get current settings:
    my $settings = Log::Lager::log_level();

    # Load from a config file:
    Log::Lager::load_config_file('path/to/file');

    # Configure explicitly.
    Log::Lager::apply_command('enable D pretty D stack D');


=head2 Log Format

Log data are emitted in JSON format to facilitate programmatic investigation
and manipulation of log output.

Log output is formatted as JSON arrays:

    [ [<TIMESTAMP>, <PID>, <LOG LEVEL>, <THREAD ID>, <TYPE>, <PACKAGE>, <SUB NAME> ], <USER INPUT>, ... ]

Timestamps are in UTC time, with an ISO 8601 style format.


=head2 Log Levels and the Log Mask

Most logging systems are based on the concept of a single logging level.  They
feature a set of log event types, each of which is assigned a value.  If the
log level is above (or below) the event's value, a message is recorded.

This module controls each log event type independent of all others using a
binary mask.  This makes it is possible to enable B<any> subset of log events.

The log mask at any given point in the execution of the program is determined
by considering several independent controls.  The base log mask is used
anywhere no more specific instructions have been given.  It is possible to
override this mask on a lexical, per package or per subroutine basis.

The log mask specifies several aspects of logging behavior for each logging
event type.  Each type may be enabled or disabled.  Enabled events may be
configured to use a either a compact or pretty printed format, whether to
produce a stack trace or not, and whether to throw an exception.

=head2 Log Masks Calculation

The log mask is determined by starting from the log mask and applying additional layer masks until all modifiers have been applied.

=head3 Order of application



      Base
      Lexical
      Package
    + Subroutine
    ------------
      Computed

Each mask beyond the base mask is stored as a difference from base.  Each mask layer is applied to the base to calculate a new mask before applying the next.


=head3 Lexical Log Mask

Lexical log mask is set by using this module in a given scope with a command string.

    {   use Log::Lager 'enable IDG stack F';
        INFO 'I am ill.';

        if( $foo ) {
            FATAL 'Oh noes'
            die "I am hit";
        }

    }

In the above example, we enable INFO, DEBUG and GUTS event types for the block.
nd to dump a stack trace if a fatal error occurs.

If the base mask is 'enable FEW', then we will have a lexical mask of 'enable FEWIDG stack F'

Lexical masks are set at compile time and may not be changed during run-time.

Use the C<lexoff> log modifier to globally disable lexical mask modifiers.  This option may be toggled at run-time.

=head3 Package and Subroutine Log Mask

Log masks may be set for specific package and subroutines.  Use 'package Foo::Bar::Baz [command here]' to configure the logging mask for a specific package.

Each time a package or subroutine mask is specified, it replaces any previous value for that particular mask.

Processesing the following two commands will leave package Foo logging with the base mask:

    package Foo enable FEWIDTG
    package Foo


=head2 What This Module Is

This module is focused on providing easy to use, flexible control of logging.

Control may be exerted by code alteration, by manipulation of the
environment, or at runtime.

Message emission is handled purely by Perl's built-in C<warn> and C<die>
functions.

=head1 EXPORTS

ALWAYS exports log level functions:

    FATAL ERROR WARN INFO DEBUG TRACE GUTS UGLY

Mnemonic: Finding essentia will increase devotion to goats.

=head1 LOGGING FUNCTIONS

=head2 Overview

This module identifies seven types of logging events.

Each logging function takes a list of arguments and emits a log message to
STDERR.

Any variable references are dumped using a compact data dumper format.  CODE
references are executed in list context, with the return added to the argument list.

Log output starts with a timestamp and the log event type the generated the message.

=head3 FATAL

Serious errors that should terminate the process should be logged as FATAL.

Enabled by default. Throw your own exception. FATAL does B<not> throw an exception by default.

=head3 ERROR

Serious errors should be logged at this level.

Enabled by default.

=head3 WARN

Minor errors should be logged at this level.

Enabled and nonfatal by default.

=head2 INFO

General information about current processing.

Disabled by default.

=head2 DEBUG

Information useful in debugging a tricky process.

Disabled by default.

=head2 TRACE

Use this when entering, or exiting subroutines, loops and/or control structures.

Disabled by default.

=head2 GUTS

Use this to log minutia and dump data structures at the most fine grained level.

Disabled by default.

=head2 UGLY

Use this to tag things that are horrible hacks that need to be removed soon, but MUST be lived with, for now.

Disabled by default.

=head1 OTHER FUNCTIONS

=head2 log_level

Emits a Log::Lager command string capable of producing the current log level.

=head2 apply_command

Run configuration commands at run-time.

=head2 load_config_file

Load a configuration file.  Once a file is loaded, it will be monitored for changes.  Any changes to the file will be detected and new configuration will be applied to a running application.

=head1 CONTROLLING LOG OUTPUT

Each log event may be configured in several ways: it may be enabled or
disabled, compact or pretty printed, and fatal or nonfatal.

This library provides facilities for altering log masks for specific
parts of a program.  Configuration can be applied over any lexical scope
at compile time.  Configuration on a per package and subroutine basis is also
possible.

=head2 Control Language

Log levels are controlled by using a simple language.

Lets start with examples of configuration commands

Enable ALL logging levels for the whole program.  Enable stack traces for
FATAL events.  Enable the lexical event mask.

    base enable FEWIDTG stack F lexon

In the current lexical scope, diasble DEBUG, TRACE and GUTS

    lexical disable DTG

In the subroutine MyPackage::sub_name, for TRACE events get stack traces and pretty print output.

    sub MyPackage::sub_name stack T pretty T

=head3 Mask selection commands

    base
    lexical
    package
    sub

    Mask selection commands identify which mask is to be modified.

    The package and sub commands both require an addition name argument to
    identify the package or subroutine maskto configure.

=head3 Configuration commands

    Configuration commands alter the behavior of a log event type for the selected mask.

    enable/disable  - turn on or off the log type
    stack/nostack   - configure stack trace generation
    compact/pretty  - format entries in a compact, single-line format, or
                      pretty print data structures.
    fatal/nofatal   - whether an event type should throw a fatal exception

=head3 Control commands

    lexon/lexoff    - globally enable or disable lexical logging masks

=head3 Level identifiers

Level identifiers are groups of 1 or more characters.  Each identifier is
the first initial of an logging event type.  For example, F indicates FATAL
and G indicates GUTS.

Identifiers may be specified inidividually or in groups.  For example,
C<enable FWE IDG> is the same as C<enable FWEIDG> and C<enable F W E I D G>.


=head2 Default Logging Level

Default logging is equivalent to C<base enable FEW>.

=head2 Modifying the Log Level

=head3 Lexical manipulation

=head4 use Log::Lager

    use Log::Lager 'IDT stack D';

Takes standard commands as a list of strings.  For example
C<use Log::Lager qw( fatal FEW );> is equivalent to C<use Log::Lager "fatal FEW";>

While this usage type is capable of handling any command, it is best to
restrict usage to configuring the lexical mask.

To simplify proper usage, this interface assumes a leading C<lexical enable>
at the beginning of a command set. For example, C<use Log::Lager 'FEWIDG';> is the
same as and C<use Log::Lager 'lexicical enable FWEIDG';>.

=head4 no Log::Lager

A simple shorthand for C<use Log::Lager 'lexical disable BLAH'>.
C<no Log::Lager XXX> is equivalent to C<use Log::Lager lexical => disable => 'XXX'>.

Command strings may consist of only log level characters (nouns).

=head3 Environment Variable

Set the C<LOGLAGER> environment variable to override B<ALL> lexical settings for
the entire script.

Assumes a leading C<enable base > at the start of the the command string:
C<LOGLAGER=FWEG foo.pl> is identical to C<LOGLAGER='enable base FWEG' foo.pl>.

Use normal command syntax.  Operates exactly as a program wide, unoverridable
C<use Log::Lager $ENV{LOGLAGER}>.

Any changes to the logging level are applied to the default logging level.


=head3 Runtime modification

The C<load_config_file> function lets you load a specific config file.  If no logfile is specified, the last file chosen will be checked for changes.  If no file is ever specified, then this function acts as a noop.

The C<apply_command> function allows any arbitrary command to be executed at runtime.

Assumes a leading C<enable base > at the start of the the command string:
C<LOGLAGER=FWEG foo.pl> is identical to C<LOGLAGER='enable base FWEG' foo.pl>.

=head1 Output Formats

=head3 Compact Formatter

Prepends each message with a time stamp and the log level.  Other than that,
works just like C<print>.  The argument list is concatenates as if with
C<join ''>.

=head3 Pretty Formatter

Prepends each message with a time stamp and the log level.  The argument list
is passed to Data::Dumper for processing.  Each item passed in will be dumped
on its own line.


