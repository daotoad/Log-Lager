package Log::Lager::Message;
use strict;
use warnings;
use Carp qw<croak>;
use Config qw( %Config );

use Hash::Util qw<lock_hash>;
use Data::Abridge qw<abridge_items_recursive>;
use Time::HiRes 'time';
 

use constant _ATTR => qw(
    loglevel
    message
    hostname
    executable
    process_id
    thread_id
    timestamp
    callstack
    subroutine
    package
    file_name
    line_number
);

use constant {
    PACKAGE     => 0,
    FILE_NAME   => 1,
    LINE_NO     => 2,
    SUBROUTINE  => 3,
    HAS_ARGS    => 4,
    WANT_ARRAY  => 5,
    EVAL_TEXT   => 6,
    IS_REQUIRE  => 7,
    HINTS       => 8,
    BIT_MASK    => 9,
    HINT_HASH   => 10,
};

use Sys::Hostname ();
my $HOSTNAME = Sys::Hostname::hostname();

BEGIN {     # Install attribute methods.

    for my $attr ( _ATTR ) {
        my $sub = sub { $_[0]->{$attr} };
        no strict 'refs';
        *{$attr} = $sub;
    }
}

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_init(@_);
    lock_hash %$self;
    
    return $self;
}

sub _init {
    my $self = shift;
    my %arg = @_;

    $self->{message} = $arg{message} 
        or croak "Attribute message required for Message object.";

    $self->{loglevel}    = $arg{loglevel};

    $self->{hostname}    = $arg{hostname}   || $HOSTNAME;
    $self->{executable}  = $arg{executable} || $0;
    $self->{process_id}  = $arg{process_id} || $$;
    $self->{thread_id}   = $arg{thread_id}  || _thread_id();

    $self->{timestamp}   = $self->_timestamp($arg{timestamp}  || () );

    $self->{expanded_format} = defined $arg{expanded_format} 
                             ? $arg{expanded_format} : 0;

    if( defined $arg{context} ) {
        my $offset = $self->_adjust_call_stack_level($arg{context});

        $self->{callstack}
            = defined $arg{callstack} ? $arg{callstack} 
            : $arg{want_stack}        ? $self->_callstack($offset) 
            :                           undef;

        my ($file, $line, $pkg, $sub) = $self->_fetch_caller_info( $offset );

        $self->{subroutine}  = defined $arg{subroutine} 
                             ? $arg{subroutine}
                             : $sub;

        $self->{package}     = defined $arg{package}    
                             ? $arg{package}
                             : $pkg;

        $self->{line_number} = defined $arg{line_number}    
                             ? $arg{line_number}
                             : $line;

        $self->{file_name}   = defined $arg{file_name}    
                             ? $arg{file_name}
                             : $file;

    }
    else {
        my @attr = qw/package subroutine file_name line_number/;
        push @attr, 'callstack' if $arg{want_stack};
        for my $attr (@attr) { 
            croak "$attr is required when context is not provided"
                unless defined $arg{$attr};

            $self->{$attr} = $arg{$attr};
        }
    }
    
}

sub _adjust_call_stack_level {
    shift;
    my $level = shift;

    my $offset = 0;
    $offset++ while caller($offset)->isa('Log::Lager::Message');
    $offset++ while caller($offset) eq ('Log::Lager');

    return $level + $offset;
}


sub _clip_string {
    my $l = length $_[0];

    return $_[0] unless $l > 25;
    
    my $h = substr $_[0], 0, 12;  
    my $t = substr $_[0], -11;

    "$h...$t";
}

sub _callstack { 
    my $self = shift;
    my $level = shift;

    my @stack;
    while (1) {
        my @env;
        my @args;
        {   package DB; 
            @env  = caller($level); 
            @args = @DB::args if $env[ Log::Lager::Message::HAS_ARGS ];
        }
        last unless defined $env[0];

        push @stack, {
            args => [ map _clip_string($_), 
                      map "$_", @args
                    ],
            file_name  => $env[FILE_NAME ],
            package    => $env[PACKAGE   ],
            line       => $env[LINE_NO   ],
            sub        => $env[SUBROUTINE],
            wantarry   => $env[WANT_ARRAY],
        }; 

        $level++;
    } 

    \@stack;
}

sub _fetch_caller_info {
    my $self  = shift;
    my $level = shift;

    my @info = caller($level);
    my ($file, $line, $pkg) = @info[FILE_NAME, LINE_NO, PACKAGE];
    @info = caller($level+1);
    my $sub = $info[SUBROUTINE];

    return ( $file, $line, $pkg, $sub );
}

sub _thread_id {
    return 0 unless $Config{usethreads};
    return 0 unless defined &threads::tid;

    return threads->tid();
}




# Create and access some JSON::XS objects for the formatters.
{   my $json;

    sub _get_compact_json {
        unless( $json ) {
            $json = JSON::XS->new()
                or die "Can't create JSON processor";
            $json->ascii(1)->indent(0)->space_after(1)->relaxed(0)->canonical(1);
        }
        return $json;
    }
}
{   my $json;
    sub _get_expanded_json {
        unless( $json ) {
            $json = JSON::XS->new()
                or die "Can't create JSON processor";
            $json->indent(2)->space_after(1)->relaxed(0)->canonical(1);
        }
        return $json;
    }
}

sub _header {
    my $self = shift;

    my $header = [
        map $self->{$_}, qw/ 
            timestamp
            loglevel
            hostname
            process_id
            thread_id
            executable
            file_name
            line_number
            package
            subroutine
        /
    ];
}

# Generic formatter that takes a configured JSON object and a data structure
# and applies one to the other.
sub _general_formatter {
    my $json = shift;
    my $self = shift;

    my $header  = $self->_header;
    my $message = $self->message;

    my @callstack = $self->{callstack} 
                  ? { callstack => $self->{callstack} } : (); 

    my $message = $json->encode(
        abridge_items_recursive(
            $header,
            @{$message},
            @callstack,
        )
    );

    return "$message\n";
}

# Actual format routines
sub _compact_formatter   { _general_formatter( _get_compact_json(), @_ )   }
sub _expanded_formatter  { _general_formatter( _get_expanded_json(),  @_ ) }

sub format {
    my $self = shift;

    return $self->{expanded_format} ? $self->_expanded_formatter() : $self->_compact_formatter;
}


sub _timestamp {
    shift;
    my $time = shift || time;

    my $millis = $time - int $time;
    $millis = int( $millis * 1000 );

    my ( $sec, $min, $hour, $mday, $mon, $year ) = gmtime($time);
    $year += 1900;
    $mon++;

    return sprintf "%04d-%02d-%02d %02d:%02d:%02d.%03d Z", $year, $mon, $mday, $hour, $min, $sec, $millis;
}

1;

=head1 NAME

Log::Lager::Message

=head1 SYNOPSIS


=head1 DESCRIPTION






