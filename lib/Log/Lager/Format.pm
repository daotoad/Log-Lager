package Log::Lager::Format;
use strict;
use warnings;
use Carp qw<croak>;
use Config qw( %Config );
use Log::Lager::Component;

sub new {
    my ($class) = @_;

    return bless {}, $class 
}

sub format {
    my ($self, $event) = @_;

    return $event->want_expanded_format()
        ? $self->_format_expanded( $event ) 
        : $self->_format_compact( $event );
}

BEGIN {
    package Log::Lager::Format::JSON;
    use strict;
    use warnings;

    use JSON qw<>;
    use Log::Lager::InlineClass;

    our @ISA='Log::Lager::Format';

    our $compact_json =
        JSON->new()
            ->ascii(1)
            ->indent(0)
            ->space_after(1)
            ->relaxed(0)
            ->allow_nonref(1)
            ->canonical(1);
    our $expanded_json =
        JSON->new()
            ->indent(2)
            ->space_after(1)
            ->relaxed(0)
            ->allow_nonref(1)
            ->canonical(1);

    sub _format_compact {
        my ($self, $event) = @_;
        my $extracted = $event->extract();
        my $message = $compact_json->encode($extracted);
        return "$message\n";
    }

    sub _format_expanded {
        my ($self, $event) = @_;
        my $extracted = $event->extract();
        my $message = $expanded_json->encode($extracted);
        return $message;
    }

    1;
}


1;

=head1 NAME

Log::Lager::Format

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 EXTENDING

=head2 Write serializer;

    _serialize_expanded 
    _serialize_compact



