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

    $self->{type}        = $arg{type}       || 'ENTRY';
    $self->{timestamp}   = $arg{timestamp}  || time;
    $self->{context_id}  = $arg{context_id} || undef;

    $self->{expanded_format} = defined $arg{expanded_format} 
                             ? $arg{expanded_format} : 0;

    if( defined $arg{context} ) {
        my $offset = $self->_adjust_call_stack_level($arg{context});
    

        $self->{callstack}
            = defined $arg{callstack} ? $arg{callstack} 
            : $arg{want_stack}        ? $self->_fetch_callstack($offset) 
            :                           undef;

        my ($sub, $pkg) = $self->_fetch_caller_info( $offset );

        $self->{subroutine} = defined $arg{subroutine} 
                            ? $arg{subroutine}
                            : $sub;

        $self->{package}    = defined $arg{package}    
                            ? $arg{package}
                            : $pkg;

    }
    else {
        my @attr = qw/package subroutine/;
        push @attr, 'callstack' if $arg{want_stack};
        for my $attr (@attr) { 
            croak "$attr is required when context is not provided"
                unless defined $arg{$attr};

            $self->{$attr} = $arg{$attr};
        }
    }
    
}

sub _adjust_call_stack_level {
    my $level = shift, shift;


    my $offset = 0;
    $offset++ while caller($offset)->isa('Log::Lager::Message');

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
    
    return @info[0,3];
}

sub _thread_id {
    return 0;
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
             type
             loglevel
             hostname
             executable
             process_id
             threadid
             context_id
             package
             subroutine
        /
    ];

    my $message = $json->encode(  abridge_items_recursive( $header, @{$self->{messages}}  )  );

    return $message;
}

# Actual format routines
sub _compact_formatter   { _general_formatter( _get_compact_json(), @_ )   }
sub _expanded_formatter  { _general_formatter( _get_expanded_json(),  @_ ) }

sub format {
    my $self = shift;

    return $self->{expanded_format} ? $self->_expanded_formatter() : $self->_compact_formatter;
}


1;

=head1 NAME

Log::Lager::Message

=head1 SYNOPSIS


=head1 DESCRIPTION






