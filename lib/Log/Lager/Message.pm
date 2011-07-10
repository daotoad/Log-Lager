package Log::Lager::Message;
use strict;
use warnings;
use Carp qw<croak>;

use Hash::Util qw<lock_hash>;

use constant _ATTR => qw(
    loglevel
    message
    hostname
    executable
    process_id
    thread_id
    type
    timestamp
    context_id
    callstack
    subroutine
    package
);

my $HOSTNAME = 'foo';

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

    $self->{loglevel} = $arg{loglevel}
        or croak "Attribute loglevel required for Message object.";

    $self->{message} = $arg{message} 
        or croak "Attribute message required for Message object.";

    $self->{hostname}    = $arg{type}       || $HOSTNAME;
    $self->{executable}  = $arg{executable} || $0;
    $self->{process_id}  = $arg{process_id} || $$;
    $self->{thread_id}   = $arg{thread_id}  || _thread_id();

    $self->{type}      = $arg{type}      || 'ENTRY';
    $self->{timestamp} = $arg{timestamp} || time;
    $self->{context_id} = $arg{context_id} || undef;

    if( defined $arg{context} ) {
        $self->{callstack} = defined $arg{callstack} 
                           ?  $arg{callstack} 
                           : $self->_fetch_callstack($arg{context});

        my ($sub, $pkg) = $self->_fetch_caller_info( $arg{context} );

        $self->{subroutine} = defined $arg{subroutine} 
                            ? $arg{subroutine}
                            : $sub;

        $self->{package}    = defined $arg{package}    
                            ? $arg{package}
                            : $pkg;

    }
    else {
        for my $attr (qw/package subroutine callstack/) { 
            croak "$attr is required when context is not provided"
                unless defined $arg{$attr};

            $self->{$attr} = $arg{$attr};
        }
    }
    
}

sub _adjust_call_stack_level {

    my $offset = 0;
    $offset++ while caller($offset)->isa('Log::Lager::Message');

    return $offset - 1;
}

sub _fetch_callstack {
    my $self = shift;
    my $level = shift;
}

sub _fetch_caller_info {
    my $self  = shift;
    my $level = shift;
    
    my $offset = $self->_adjust_call_stack_level($level);
    
    my @info = caller($level + $offset);
    
    return @info[0,3];
}

sub _thread_id {
    return 0;
}



1;

=head1 NAME

Log::Lager::Message

=head1 SYNOPSIS

Provides a way to override normal Log::Lager output conventions.

Should be used by libraries that want to work with Log::Lager rather than by end users.



