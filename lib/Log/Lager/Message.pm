package Log::Lager::Message;
use strict;
use warnings;
use Carp qw<croak>;

use Hash::Util qw<lock_hash>;
use Data::Abridge qw<abridge_items_recursive>;

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

use Sys::Hostname ();
my $HOSTNAME = Sys::Hostname::hostname();

BEGIN {
    no strict 'refs';
    for my $attr ( _ATTR ) {
        *{$attr} = sub {  $_[0]->{$attr} };
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
            : $arg{want_stack}        ? $self->_fetch_callstack($offset) 
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

sub _fetch_callstack {
    my $self = shift;
    my $level = shift;

}

sub _fetch_caller_info {
    my $self  = shift;
    my $level = shift;

    my @info = caller($level);
    my ($file, $line, $pkg) = @info[1, 2, 0];
    @info = caller($level+1);
    my $sub = $info[3];


    return ( $file, $line, $pkg, $sub );
}

sub _thread_id {
    my $tcfg = exists $INC{threads}; 

    return 0 unless $tcfg;

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

# Generic formatter that takes a configured JSON object and a data structure
# and applies one to the other.
sub _general_formatter {
    my $json = shift;
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

    my $message = $json->encode(  abridge_items_recursive( $header, @{$self->{message}}  )  );

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

    my ( $sec, $min, $hour, $mday, $mon, $year ) = gmtime($time);
    $year += 1900;
    $mon++;
    return sprintf "%04d-%02d-%02d %02d:%02d:%02d Z", $year, $mon, $mday, $hour, $min, $sec;
}

1;

=head1 NAME

Log::Lager::Message

=head1 SYNOPSIS


=head1 DESCRIPTION






