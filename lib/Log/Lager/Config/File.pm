package Log::Lager::Config::File;
our @ISA = qw< Log::Lager::Config >;

use strict;
use warnings;
use Carp qw( croak );
$Carp::Internal{__PACKAGE__}++;

use JSON  qw<>;
use constant STAT_INODE => 1;

use constant {
    NAME        => 0,
    CHECK_FREQ  => 1,
    NEXT_CHECK  => 2,
    LAST_LOAD   => 3,
};

our $DEFAULT_CHECK_FREQUENCY = 60;

sub new {
    my ($class, %opt) = @_;

    my $self = bless [], $class;
    $self->[NAME]       = delete $opt{file_name};
    $self->[CHECK_FREQ] = delete $opt{check} || $DEFAULT_CHECK_FREQUENCY;
    $self->[NEXT_CHECK] = 0;
    $self->[LAST_LOAD] = 0;

    my @bad = sort keys %opt;
    croak "Invalid parameters for new Log::Lager::Config::File - @bad"
        if @bad;

    croak "Required parameter 'file_name' is not defined"
        unless $self->[NAME];

    return $self;
}

sub dump_config {
    my ($class) = @_;
    my $self = [];
    if( ref $class ) {
        $self = $class;
        $class = ref $class;
    }
    my $cfg = $class;
    $cfg =~ s/^Log::Lager::Config:://;

    my @config = (
       $cfg => {
           file_name => $self->[NAME],
           check     => $self->[CHECK_FREQ],
       } 
    );

    return @config;
}

sub load {
    my ($self,$last) = @_;

    # TODO overload ==
    if( $last && $self == $last ) {
        return $last->load();
    }

    my $mtime = (stat $self->[NAME])[9] // 0;
    return if $self->[LAST_LOAD] > $mtime;

    require IO::File;
    my $fh = IO::File->new( $self->[NAME], '<' )
        or do {
        Log::Lager::ERROR( "Error opening config file", $self->[NAME], $! );
            return;
        };

    my @lines = <$fh>;
    my $config = Log::Lager::Util->unpack_json_config( join '', @lines );

    $self->[NEXT_CHECK] = time + $self->[CHECK_FREQ];

    return $config;
}



__PACKAGE__;
