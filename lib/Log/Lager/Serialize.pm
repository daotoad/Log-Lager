package Log::Lager::Serialize;
use strict;
use warnings;
use Carp qw<croak>;
use Config qw( %Config );
use Log::Lager::Component;



sub new {
    my ($class) = @_;

    return bless {}, $class 
}

sub serialize {
    my ($self, $expanded, $event) = @_;

    return $expanded
        ? $self->_serialize_expanded( $event ) 
        : $self->_serialize_compact( $event );
}

BEGIN {
    package Log::Lager::Serialize::JSON;
    use strict;
    use warnings;

    use JSON qw<>;
    use Log::Lager::InlineClass;

    our @ISA='Log::Lager::Serialize';

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

    sub _serialize_compact {
        my ($self, $event) = @_;
        my $message = $compact_json->encode($event);
        return "$message\n";
    }

    sub _serialize_expanded {
        my ($self, $event) = @_;
        my $message = $expanded_json->encode($event);
        return $message;
    }

    1;
}


1;

=head1 NAME

Log::Lager::Serialize

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 EXTENDING

=head2 Write serializer;

    _serialize_expanded 
    _serialize_compact



