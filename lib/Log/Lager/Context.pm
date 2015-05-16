package Log::Lager::Context;
use strict;
use warnings;
use Config          qw<%Config>;
use Sys::Hostname   qw<>;

use Data::Abridge   qw<abridge_items_recursive>;

use constant {
    _args           => 0,
    _file           => 1,
    _hints_hash     => 2,
    _line           => 3,
    _ll_level       => 4,
    _package        => 5,
    _stack_frame    => 6,
    _sub            => 7,
};
our $HOSTNAME = Sys::Hostname::hostname();

sub new {
    my ( $class, $level ) = @_;

    # NOTE:  May need to capture sub at level as well as sub+1
    my @caller_data = ($class->Caller($level))[0,1,2,10,11,12];
    return unless @caller_data;

    my $self = [];
    my ( $package, $file, $line, 
         $hints_hash, $stack_frame, $sub,
     ) = @caller_data;

    bless $self, $class;
    $self->[_file]        = $file;
    $self->[_line]        = $line;
    $self->[_package]     = $package;
    $self->[_sub]         = $sub;
    $self->[_ll_level]    = $level;
    $self->[_stack_frame] = $stack_frame;
    $self->[_hints_hash]  = $hints_hash;
    $self->[_args]        = undef;

    return $self;
}

sub get_hints {
    my ($self, @keys) = @_;

    my @hints = @{$self->[_hints_hash]}{@keys};

    return wantarray ? @hints : $hints[0];
}

sub AsHash {
    my ($class, $level) = @_;
    my $self = ref $class ? $class : $class->new($level);
    return unless $self;

    my %context = (
        file    => $self->[_file],
        package => $self->[_package],
        sub     => $self->[_sub],
        line    => $self->[_line],
    );

    $context{args} = $self->[_args] if $self->[_args];

    return %context;
}

sub AsArray {
    my ($class, $level) = @_;
    my %context = $class->as_hash();

    my @array = @context{qw/file line package sub /};
    push @array, $context{args}
        if exists $context{args};

    return @array;
}

sub get {
    my ($self, @args) = @_;
    my %c = $self->AsHash();

    return @c{@args};
}

sub get_args {
    my ($self) = @_;

    return $self->[_args]
        if defined $self->[_args];

    my $frame = $self->[_stack_frame];

    my $args = $DB::args[$frame];
    my $abridged = abridge_items_recursive( $args );

    $self->[_args] = $abridged;

    return $abridged;
}

# Returns the same stuff as built-in caller()
# Except adds SUB called from and STACK_FRAME
sub Caller {
    my ($class, $target_level, $allow_internal) = @_;
    my $orig = $target_level;
    $target_level += 1;

    return CORE::caller($target_level)
        if $allow_internal;

    my @info;
    my $level = 1;
    do {
        @info = CORE::caller($level);
        return unless @info;

        no warnings 'uninitialized';
        if ( Log::Lager::Component->is_registered($info[0]) ) {
            $target_level += 1;
        }
        $level += 1;

    } while ( $level <= $target_level );

    my $sub_context = (CORE::caller($level))[3];
    push @info, $sub_context, $level-1;

    return wantarray ? @info : $info[0];
}

sub ProcessInfo {
    my ($class) = @_;

    my $pid = $$;
    my $thread_id = $Config{usethreads} && defined &threads::tid
        ? threads->tid()
        : 0;
    my $executable = $0;
    my $host = $HOSTNAME;

    return $executable, $host, $pid, $thread_id;
}

sub StackTrace {
    my ($class, $level, $type) = @_;
    my $self = ref $class ? $class : $class->new( $level );
    return unless $self;

    my @trace = ( $self, (ref $self)->StackTrace($self->[_ll_level]+1) );

    @trace = map $_->as_hash(), grep defined, @trace;

    return @trace;
}

1;
