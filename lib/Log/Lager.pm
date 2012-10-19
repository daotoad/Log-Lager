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
use Log::Lager::Spitter qw< >;

*INTERNAL_TRACE = sub () { 0 }
    unless defined &INTERNAL_TRACE;

# Global configuration
our $CONFIG;
# === Global mask variables ===
# These global masks are controlled as a side effect of _parse_commands();
our $BASE_MASK;          # Base mask that all other masks are calculated relative to
our %PACKAGE_MASK;       # Storage for package specific masks
our %SUBROUTINE_MASK;    # Storage for sub specific masks

# === Global config ===
# Non-mask variables that store current configuration information
our $ENABLE_LEXICAL;     # Boolean flag for lexical controls
our $SPITTER;     # Log::Lager::Spitter object

our $PREVIOUS_CONFIG_FILE = '';
our $CONFIG_LOAD_TIME     = 0;
our $DEFAULT_MESSAGE_CLASS   = 'Log::Lager::Message';
our $DEFAULT_MESSAGE_OPTIONS = {};

# === Configure Log Levels ===
use constant {      # Indexes of the various elements in the LOG_LEVELS ARRAY
    MASK_CHAR    => 0,
    FUNCTION     => 1,
    BITFLAG      => 2,
};
my @LOG_LEVELS = (
    [ F => FATAL => 0x01 ],
    [ E => ERROR => 0x02 ],
    [ W => WARN  => 0x04 ],
    [ I => INFO  => 0x08 ],
    [ D => DEBUG => 0x10 ],
    [ T => TRACE => 0x20 ],
    [ G => GUTS  => 0x40 ],
    [ U => UGLY  => 0x80 ],
);
my @LOG_FUNCTIONS = map $_->[FUNCTION], @LOG_LEVELS;

use constant {  # Number of bits to left shift for access to different parts of config mask.
    ENABLE_BITSHIFT   => 0,
    FATALITY_BITSHIFT => 8,
    PRETTY_BITSHIFT   => 16,
    STACK_BITSHIFT    => 24,
};

# Process @LOG_LEVELS for easy access
my @MASK_CHARS = map $_->[MASK_CHAR], @LOG_LEVELS;
our %MASK_CHARS; @MASK_CHARS{ @MASK_CHARS } = @LOG_LEVELS;
my $MASK_REGEX = join '', keys %MASK_CHARS;

# === Code Generation ===
# Generate Log Level functions
{   no strict 'refs';
    for my $l ( @LOG_LEVELS ) {
        my $func = $l->[FUNCTION];
        my $level = $l->[MASK_CHAR];
        *$func = sub { _handle_message( $level, @_ ); };
    }
}

# === Initialize masks  ===
our @DEFAULT_BASE = qw(
    enable   FEW disable     IGTDU
    fatal        nonfatal FEWIGTDU
    stack        nostack  FEWIGTDU
    pretty       compact  FEWIGTDU
);
_parse_commands( [0,0], 'enable', $ENV{LOGLAGER} )
    if defined $ENV{LOGLAGER};

# Bitmask manipulation
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

        my $on_bits  = _mask_string_to_bitmask($mask->$on_method);
        my $off_bits = _mask_string_to_bitmask($mask->$off_method);
        $on  |= $on_bits  << $shift;
        $off |= $off_bits << $shift;
    }

    return ($on, $off);
}

sub _apply_bits_to_mask {
    my ($on_bits, $off_bits, $mask ) = @_;

    $mask->enable(  _bitmask_to_mask_string( $on_bits,   ENABLE_BITSHIFT ));
    $mask->disable( _bitmask_to_mask_string( $off_bits,  ENABLE_BITSHIFT ));

    $mask->stack(   _bitmask_to_mask_string( $on_bits,   STACK_BITSHIFT ));
    $mask->nostack( _bitmask_to_mask_string( $off_bits,  STACK_BITSHIFT ));

    $mask->pretty(   _bitmask_to_mask_string( $on_bits,  PRETTY_BITSHIFT ));
    $mask->compact( _bitmask_to_mask_string( $off_bits,  PRETTY_BITSHIFT ));

    $mask->fatal(    _bitmask_to_mask_string( $on_bits,  FATALITY_BITSHIFT ));
    $mask->nonfatal( _bitmask_to_mask_string( $off_bits, FATALITY_BITSHIFT ));

    return;
}

# Configuration

sub _configure_message_object {
    my $object_pkg  = shift;
    my $object_opts = shift;

    return unless defined $object_pkg;
    return unless length $object_pkg;

    return unless ref $object_opts eq 'HASH';

    eval << "    END"
       require $object_pkg
            unless $object_pkg->isa('Log::Lager::Message');
       $object_pkg->isa('Log::Lager::Message');
    END
        or do {
            warn "Error loading $object_pkg: $@\n";
            return;
        };

    $DEFAULT_MESSAGE_CLASS   = $object_pkg;
    $DEFAULT_MESSAGE_OPTIONS = $object_opts;

    return 1;
}

sub _parse_commands {
    my $masks = shift;
    my @commands = @_;

    my $lex_masks = [@$masks];  # Copy lex masks to avoid leaky side effects
    my $mask = Log::Lager::Mask->parse_command( @commands );
    {   my @bitmasks = _convert_mask_to_bits( $mask );
        $lex_masks->[0] |=  $bitmasks[0];
        $lex_masks->[1] |=  $bitmasks[1];
    }

    if( Log::Lager::INTERNAL_TRACE() ) {
        printf STDERR "SETTING LEXICAL MASK: %08X\n", $lex_masks;
        use Data::Dumper; print Dumper $mask;
    }

    return $lex_masks;
}

sub apply_config {
    my $config = shift || $CONFIG;

    # apply changes to BASE
    my $bm = $config->get_mask( 'base' );
    if( Log::Lager::INTERNAL_TRACE() ) {
        printf STDERR "BASE MASK: %08X\n", $BASE_MASK;
        use Data::Dumper; print Dumper $bm
    }
    if( defined $bm ) {
        my @bitmasks = _convert_mask_to_bits($bm);
        $BASE_MASK |=  $bitmasks[0];
        $BASE_MASK &= ~$bitmasks[1];
    }
    printf STDERR "BASE MASK: %08X\n", $BASE_MASK
        if Log::Lager::INTERNAL_TRACE();

    # Package:
    for my $name ( $config->package_names ) {

        my $mask = $config->get_mask( package => $name);

        my @bitmasks = _convert_mask_to_bits( $mask );
        if( @bitmasks ) {
            $PACKAGE_MASK{$name} = \@bitmasks;
        }
        else {
            delete $PACKAGE_MASK{$name};
        }
    }

    # Subroutine masks
    for my $name ( $config->sub_names ) {

        $SUBROUTINE_MASK{$name} = [0,0];
        my $mask = $config->get_mask( 'sub' => $name);

        my @bitmasks = _convert_mask_to_bits( $mask, 0, 0 );
        if( $bitmasks[0] == 0 and $bitmasks[1] == 0 ) {
            delete $SUBROUTINE_MASK{$name};
        }
        else {
            $SUBROUTINE_MASK{$name} = \@bitmasks;
        }
    }

    # Output
    $SPITTER = $config->get_emitter( $SPITTER );

    # Lexical control flag
    my $lexon = $config->lexicals_enabled();
    $ENABLE_LEXICAL = $lexon if defined $lexon;
    $ENABLE_LEXICAL = 1 if $] < 5.009;

    _configure_message_object( $config->message_type, $config->message_options );

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


# Message output

# This function provides the meat of the logic behind the log level functions.
sub _handle_message {
    my $level = shift;

    if( Log::Lager::INTERNAL_TRACE() ) {
        printf STDERR "MESSAGE at $level : @_ ";
        use Data::Dumper; print Dumper \@_;
    }

    croak "Invalid log level '$level'"
        unless exists $MASK_CHARS{$level};

    my ($on_bit, $die_bit, $pretty_bit, $stack_bit ) =_get_bits(2, $MASK_CHARS{$level}[BITFLAG]);
        if( Log::Lager::INTERNAL_TRACE() ) {
            STDERR->printflush( "MESSAGE BITS: ON-$on_bit DIE-$die_bit PRETTY-$pretty_bit STACK-$stack_bit\n" );
        }


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
        $msg = $DEFAULT_MESSAGE_CLASS->new(
            %{$DEFAULT_MESSAGE_OPTIONS},
            context         => 0,
            loglevel        => $MASK_CHARS{$level}[FUNCTION],
            message         => \@messages,
            want_stack      => $stack_bit,
            expanded_format => $pretty_bit,
        );
    }

    if ($on_bit) {
        my $spitter = $SPITTER;
        $spitter  ||= Log::Lager::Spitter->default();

        if( Log::Lager::INTERNAL_TRACE() ) {
            STDERR->printflush( "SPIT with $spitter / $SPITTER - $msg\n" );
#use Data::Dumper; STDERR->printflush( Dumper $msg );
        }

        $spitter->spit( $level, $msg );

        if( $die_bit ) {
           die "$msg->format\n";
        }

        load_config_file();
    }

    die $return_exception    if defined $return_exception;
    return                   if !defined wantarray;
    return @return_values    if wantarray;
    return $return_values[0] if @return_values <= 1;
    die "Have multiple return values when wantarray is false\n";
}


# === Logging configuration functions ===
# These functions allow access to logging configuration.

# Apply a generic command set to the current configuration
sub apply_command {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };
    _parse_commands( [0,0], 'enable', @_ ) or die "Oops";
}


# Load a configuration file as needed.
# This function is looks for changes in the configured file before processing it.
# It is safe to call this function a lot.
sub load_config_file {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };

    my $path = @_ ? shift : $PREVIOUS_CONFIG_FILE;

    return unless $path;

    if( $path eq $PREVIOUS_CONFIG_FILE ) {
        my $mtime = (stat $path)[9];
        return if $CONFIG_LOAD_TIME > $mtime;
    }

    $CONFIG_LOAD_TIME = time;
    $PREVIOUS_CONFIG_FILE = $path;

    open my $fh, '<', $path
        or do {
            warn "Error opening config file '$path': $!\n";
            ERROR( "Error opening config file", $path, $! );
            return;
        };

    my @lines = <$fh>;
    chomp @lines;
    s/#.*$// for @lines; # Remove comments

    # Get rid of trailing blank lines.
    pop @lines while @lines && $lines[-1] =~ /^\s*$/;

    # Check for END token.
    if( $lines[-1] =~ /^\s*END\s*$/ ) {
        pop @lines;
    }
    else {
        warn "No END token in configuration file.\n";
        ERROR( "No END token in configuration file.", $path, \@lines );
        return;
    }

    eval {
        apply_config( @lines );
        1;
    }
    or do {
        warn "Error parsing configuration command: $@\n";
        ERROR( message => "Error parsing configuration file.", $path, $@ );
        return;
    };

    return;

}


# Non-standard import method.
# Parse a log configuration command.
# May also import log spitter functions if not already present.
#
# Injects a "lexical enable" at start of command
sub import {
    shift;

    my $caller = caller;

    my %import;
    @import{ @LOG_FUNCTIONS } = @LOG_FUNCTIONS;


    # Got configuration hash
    # TODO flesh out configuration loading
    if( ref $_[0] ) {
        my $config = shift;
        configure( $config );

        # TODO - better error messages for bad settings.
        for ( keys %{$config->{import_as}} ) {
            $import{$_} = $config->{import_as}{$_};
        }
        for ( keys %{$config->{no_import}} ) {
            delete $import{$_}
                if exists $import{$_};
        }

    }

    # Import functions
    # Skip if this is not the first time through
    my $hints = (caller(1))[10];
    unless( defined $hints->{'Log::Lager::Log_enable'} ) {
        no strict 'refs';

        # TODO look for import / noimport in MASK and import as needed.
        for my $l ( @LOG_LEVELS ) {
            my $func = $l->[FUNCTION];
            next unless exists $import{$func};

            my $level = $l->[MASK_CHAR];

            my $dest_func = "${caller}::$import{$func}";
            *$dest_func = \&$func;
        }
    }

    if( @_ ) {
        # Apply log level mask
        my $mask = [
            $^H{'Log::Lager::Log_enable'},
            $^H{'Log::Lager::Log_disable'}
        ];
        $mask = _parse_commands( $mask, 'enable',  @_ ) if @_;

        $^H{'Log::Lager::Log_enable'}  = defined($mask->[0]) ? $mask->[0] : 0;
        $^H{'Log::Lager::Log_disable'} = defined($mask->[1]) ? $mask->[1] : 0;
    }

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

    my $mask = [
        $^H{'Log::Lager::Log_enable'},
        $^H{'Log::Lager::Log_disable'}
    ];
    $mask = _parse_commands( $mask , 'lexical disable', @commands );
    $^H{'Log::Lager::Log_disable'} = $mask->[1];

    return;
}

# TODO  Rewrite to dump calculated log level in Log::Lager command argot
sub log_level {
    shift if @_ && eval{ $_[0]->isa( __PACKAGE__ ) };

    die "Need to fix this";
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

This modules provides serveral unique features: orthogonal configuration of
log levels, lexical log level configuration, runtime logging controls and a
parsable log format.

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


