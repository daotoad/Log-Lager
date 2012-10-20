package Log::Lager::Mask;
use strict;
use warnings;
use Carp qw<croak>;
use Data::Dumper;

use Scalar::Util qw< blessed >;
use Hash::Util  qw< lock_keys >;




use overload '""' => 'as_string';
use constant GROUP_PAIRS => (
    [qw/ enable  disable /],
    [qw/ stack   nostack /],
    [qw/ pretty  compact /],
    [qw/ fatal   nonfatal /],
);
use constant GROUPS => map @$_, GROUP_PAIRS;
our $GROUP_REGEX = join '|', GROUPS;

use constant MASK_CHARS => qw( F E W I D T G U );
our $MASK_REGEX = join '', '[', MASK_CHARS, ']';

# === Generate methods === #
{    no strict 'refs';

    # Make subs like:
    # sub enable {
    #     my $self = shift;
    #     $self->toggle_mask( enable => disable => @_ );
    # }
    for ( GROUP_PAIRS ) {
        my @pair = @$_;

        *{$pair[0]} = sub {
            my $self = shift;
            $self->toggle_mask( @pair[0,1], @_ )
        };

        *{$pair[1]} = sub {
            my $self = shift;
            $self->toggle_mask( @pair[1,0], @_ )
        };
    }

}

# Object structure:
# { __IS_SET__ => undef, #
#   enable  => { F => 1, E => 0, ... },
#   disable => { F => 0, E => 1, ... },
#   ...
# }
# Three value logic -
#  1 = TRUE
#  0 = FALSE
#  missing = not set
sub new {
    my $class = shift;

    my $self = {};

    bless $self, $class;

    return $self;
}

sub parse_command {
    my $class = shift;
    my $command_string = join ' ', @_;
    $command_string =~ s/^\s*//;
    my @tokens = split /\s+/s, $command_string;

    my $mask = $class->new();

    my $term;
    for ( @tokens ) {
        if ( /^($Log::Lager::Mask::MASK_REGEX+)$/ and defined $term ) {
            $mask->$term($_);
        }
        elsif ( /^($GROUP_REGEX)$/ ) {
            $term = $1;
        }
        else {
            Log::Lager::ERROR( "Invalid token '$_' in command string", $_, $command_string );
            die "Invalid token '$_' in command string '$command_string'\n";
            return;
        }
    }

    return $mask;
}
sub toggle_mask {
    my $self  = shift;
    my $on    = shift;
    my $off   = shift;
    my $chars = shift || '';

    $self->{__IS_SET__} = 1;

    my @chars = split //, $chars;

    for my $c ( @chars ) {
        $self->{$on}{$c}  = 1;
        $self->{$off}{$c} = 0
            if exists $self->{$off}{$c};
    }
    return join '',
        grep $self->{$on}{$_},
        MASK_CHARS;
}



# Mark all flags in one side of each pair
sub complete {
    my $self = shift;

    for my $pair ( GROUP_PAIRS ) {
        my ($special, $default) = @$pair;
        my %seen;
        $seen{$_}++ for keys %{$self->{$default}}, keys %{$self->{$special}};

        my @missing = grep !exists $seen{$_}, MASK_CHARS;

        $self->$default( join '', @missing );
     }
}

sub as_string {
    my $self = shift;

    my $string = join ' ',
        map "@$_",
        grep $_->[1],
        map [$_, $self->$_()], GROUPS;

    return $string;
}

sub changed {
    my $self = shift;
    return $self->{__IS_SET__};
}

1;


=head1 NAME

Log::Lager::CommandParser

=head1 SYNOPSIS

Provides command parsing for the Log::Lager module.

    use Log::Lager::CommandParser 'parse_command';

    # Parse a command and get a CommandResult object back:
    my $result = parse_command( 'lexical enable FEW stack F' );


=head1 RELATED OBJECTS


=head2 CommandResult

Collects the results of parsing a command.

=head3 Attributes

 lexical          - The lexical logging mask. A C<Log::Lager::Mask> object.
 lexicals_enabled - A flag indicating if lexical logging effects are enabled or
                    disabled.  This flag is a three-valued boolean, where B<undef> means no specified value.
 output           - Contains the output type.  Must be one of C<stderr>, C<syslog> or C<file>.
                    syslog_identity  - Contains the identity string for syslog output.
 syslog_identity  - Contains the identity string for syslog output.
 syslog_facility  - Contains the facility name for syslog output.
 file_name        - Contains the name of the file to append log messages to.
 file_perm        - Contains the permissions of the log file if we log to file.



=head2 Mask

=head3 Attributes



