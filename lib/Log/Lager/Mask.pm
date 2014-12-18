package Log::Lager::Mask;
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
our $MASK_REGEX = join '', MASK_CHARS;
my %GROUP = map {$_ => 1} GROUPS;

my %OPPOSITE = (%GROUP, reverse %GROUP);


sub new {
    my $class = shift;

    my $self = {};

    bless $self, $class;

    return $self;
}

# TODO are set_mask and _toggle redundant?  Which to remove?
sub set_mask {
    my( $self, $on, $chars ) = @_;

    my $off = $OPPOSITE{$on}
        or die "Illegal group '$on'";

    my @chars = split //, $chars;

    return unless @chars;
    $self->{__IS_SET__} = 1;

    for my $c ( @chars ) {
        $self->{$on}{$c}  = 1;
        $self->{$off}{$c} = 0
            if exists $self->{$off}{$c};
    }

    return $self;
}

sub get_mask {
    my( $self, $on, $chars ) = @_;
    return join '',
        grep $self->{$on}{$_},
        MASK_CHARS;
}

sub _toggle_mask {
    my $self  = shift;
    my $on    = shift;
    my $off   = shift;
    my $chars = shift || '';

    my @chars = split //, $chars;

    if (@chars) {
        $self->{__IS_SET__} = 1;

        for my $c ( @chars ) {
            $self->{$on}{$c}  = 1;
            $self->{$off}{$c} = 0
                if exists $self->{$off}{$c};
        }
    }
    return join '',
        grep $self->{$on}{$_},
        MASK_CHARS;
}

sub enable {
    my $self = shift;
    $self->_toggle_mask( enable => disable => @_ );
}

sub disable {
    my $self = shift;
    $self->_toggle_mask( disable => enable => @_ );
}

sub pretty {
    my $self = shift;
    $self->_toggle_mask( pretty => compact => @_ );
}

sub compact {
    my $self = shift;
    $self->_toggle_mask( compact => pretty => @_ );
}

sub stack {
    my $self = shift;
    $self->_toggle_mask( stack => nostack => @_ );
}

sub nostack {
    my $self = shift;
    $self->_toggle_mask( nostack => stack => @_ );
}

sub nonfatal {
    my $self = shift;
    $self->_toggle_mask( nonfatal => fatal => @_ );
}

sub fatal {
    my $self = shift;
    $self->_toggle_mask( fatal => nonfatal => @_ );
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

sub apply_string {
    my $self = shift;
    my $log_level_string = shift;

    my @tokens = split /\s+/, $log_level_string;

    my $level = 'enable';
    for my $token ( @tokens ) {
        if( $GROUP{$token} ) {
            $level = $token;
        }
        else {
            $self->$level($token);
        }
    }
        
}

1;
__END__

=for Pod::Coverage new 


=head1 NAME

Log::Lager::Mask

=head1 SYNOPSIS

Provides utilities for working with bitmasks in Log::Lager

    use Log::Lager::Mask

=head2 DESCRIPTION

=head2 Methods


=head2 new
=head2 set_mask

Given a logging control attribute (pretty, enable, etc) and a string of mask
characters (FEWTDIGU), set the mask for that control group.

=head2 get_mask

Given a logging control attribute, return the associated mask string.

=head2 enable
=head2 disable
=head2 pretty
=head2 compact
=head2 stack
=head2 nostack
=head2 nonfatal
=head2 fatal

Given a mask string, set the mask for the associated control attribute.

=head2 complete
=head2 as_string
=head2 changed
=head2 apply_string




