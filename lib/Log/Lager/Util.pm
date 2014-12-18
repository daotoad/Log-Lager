package Log::Lager::Util;

use strict;
use warnings;
use Log::Lager::Component;

use JSON;

sub caller {
    my ($class, $target_level, $allow_internal) = @_;
    my $orig = $target_level;
    $target_level += 1;

    return CORE::caller($target_level)
        if $allow_internal;

    my @info;
    my $level = 1;
    do {
        @info = CORE::caller($level);
        no warnings 'uninitialized';
        if ( Log::Lager::Component->is_registered($info[0]) ) {
            $target_level += 1;
        }
        $level += 1;

    } while ( $level <= $target_level );

    my $sub_context = (CORE::caller($level))[3];
    push @info, $sub_context;

    return wantarray ? @info : $info[0];
}

sub unpack_json_config {
    my ( $class, $string ) =  @_;

    my $json = JSON->new()->utf8->relaxed();

    my $config = $json->decode( $string );

    return $config;
}

1;

__END__

=head1 NAME

Log::Lager::Util - Miscellaneous shared LL code.

=head1 SYNOPSIS



=head1 DESCRIPTION

