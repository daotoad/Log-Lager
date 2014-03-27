package Log::Lager::Tap::Syslog;
our @ISA = qw< Log::Lager::Tap >;

use strict;
use warnings;
use Carp qw( croak );
$Carp::Internal{__PACKAGE__}++;


use constant {
    IDENTITY    => 0,
    FACILITY    => 1,
    LEVELS      => 2,
    OPENED      => 3,
};

my %DEFAULT_LOG_LEVELS = (
    F => 'LOG_CRIT',
    E => 'LOG_ERR',
    W => 'LOG_WARNING',
    I => 'LOG_INFO',
    D => 'LOG_DEBUG',
    T => 'LOG_DEBUG',
    G => 'LOG_DEBUG',
    U => 'LOG_DEBUG',
);

sub new {
    my ($class, %opt) = @_;

    my $self = bless [], $class;
    $self->[IDENTITY] = delete $opt{identity};
    $self->[FACILITY] = delete $opt{facility};

    my $user_levels = delete $opt{log_levels} || {};
    $self->[LEVELS] = {
        %DEFAULT_LOG_LEVELS,
        %$user_levels
    };


    my @bad = sort keys %opt;
    croak "Invalid options for new Log::Lager::Output::Syslog - @bad"
        if @bad;

    croak "Invalid log levels for Log::Lager::Tap::Syslog"
        if keys %{$self->[LEVELS]} != keys %DEFAULT_LOG_LEVELS;

    return $self;
}

sub dump_config {
    my ($class) = @_;
    my $self = [];
    if( ref $class ) {
        $self = $class;
        $class = ref $class;
    }

    my @config = (
       $class->_tap_name() => {
           identity   => $self->[IDENTITY],
           facility   => $self->[FACILITY],
           log_levels => { %{$self->[LEVELS]} },
       } 
    );

    return @config;
}

sub deselect {
    my ($self) = @_;

    require Sys::Syslog;
    Sys::Syslog::closelog();
    $self->[OPENED] = 0;

    return 1;
}

sub select {
    my ($self) = @_;

    require Sys::Syslog;
    my $fh = Sys::Syslog::openlog( $self->[IDENTITY], 'ndelay,nofatal', $self->[FACILITY] )
        or die "Error opening syslog - $!\n";
    $self->[OPENED] = 1;

    return $self;
}

sub gen_output_function {
    my ($self) = @_;
    my %levels = %{$self->[LEVELS]};

    return sub {
        my ($level, $fatal, $message) = @_;
        my $msg = $message->format() || '';
        Sys::Syslog::syslog( $levels{$level}, "%s", $msg );
        die "$msg\n" if $fatal;
        return;
    };
}

__PACKAGE__;
