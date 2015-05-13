package Log::Lager::Capture::STDERR;
use strict;
use warnings;
use Log::Lager      qw<>;
use Log::Lager::Component;
use Tie::Handle;
use Scalar::Util    qw<weaken>;
use JSON;

our @ISA = qw< Log::Lager::Capture  Tie::Handle >;
our $SINGLETON;

use constant {
    DUP    => 0,
    EMIT   => 1,
    HANDLE => 2,
    CLASS  => 3,
    CONFIG => 4,
    LEVEL  => 5,
    DUP_HANDLE => 6,
};

    my %LEVEL_HANDLER = map {
        $_ => 1
    } qw< FATAL ERROR WARN TRACE DEBUG GUTS INFO UGLY >;

sub new {
    my($class, %opt) = @_;
    my $opt = _normalize_config( \%opt );

    my $level       = $opt->{level};
    my $dup         = $opt->{dup};
    my $event_class   = $opt->{event_class};
    my $event_config  = $opt->{event_config};

    my $self = bless [], ref $class || $class;

    $self->[LEVEL]  = $level;
    $self->[DUP]    = $dup;
    $self->[HANDLE] = \*STDERR;
    $self->[CONFIG] = $event_config;
    $self->[CLASS]  = $event_class;
    $self->[DUP_HANDLE] = $self->_dup_handle();
    $self->[EMIT]   = $self->_generate_emitter();

    return $self;
}

sub enable {
    my ($class, %opt) = @_;

    return $SINGLETON if $SINGLETON;

    my $self = $class->new(%opt);

    tie *{$self->[HANDLE]}, 'Log::Lager::Capture::_impl', $self->[EMIT]
        or die "Error creating tied handle.";


    $SINGLETON = $self;

    return $self;;
}

sub config {
    my ($self) = @_;

    return {
        level       => $self->[LEVEL],
        dup         => $self->[DUP],
        event_class   => $self->[CLASS],
        event_config  => $self->[CONFIG],
    };
}

sub config_eq {
    my ($self, %opt) = @_;
    my $cmp_opt  = _normalize_config( \%opt );
    my $self_opt = $self->config();

    my $json = JSON->new()->canonical()->utf8();
    $_ = $json->encode($_)
        for ( $cmp_opt, $self_opt );

    return $cmp_opt eq $self_opt ? 1 : 0;
}

sub _normalize_config {
    my ($opt) = @_;

    my $level      = delete $opt->{level};
    my $dup        = delete $opt->{dup};
    my $event_class  = delete $opt->{event_class};
    my $event_config = delete $opt->{event_config};

    $level ||= 'ERROR';
    die "Cannot log STDERR at level '$level', level does not exist\n"
        if ! $LEVEL_HANDLER{$level};

    if( $event_config ) {
        eval { $event_config = [ %$event_config ]; 1 }
            or
        eval { $event_config = [ @$event_config ]; 1 }
            or
        die "If defined, event_config must be an array or hash reference\n";

        die "event_class must be set when event_config is set\n"
            if ! $event_class;
    }

    if ( $event_class ) {
        die "event_config must be set when event_class is set\n"
            if ! $event_config;
    }

    return {
        event_config  => $event_config,
        event_class   => $event_class,
        level       => $level,
        dup         => $dup,
    };
}

sub disable {
    my ($self) = @_;

    $self->[EMIT] = undef;
    untie *{$self->[HANDLE]};

    $SINGLETON = undef;

    return;
}

sub _dup_handle {
    my ($self) = @_;
    # Copy (dup) STDERR to a different handle:
    my $fd = fileno($self->[HANDLE]);
    if( ! defined $fd ) {
        die( "Can't dup STDERR. STDERR may already be tied. Capture::STDERR will not retie it.\n" );
        return;
    }
    open my $error, '>>&=', $fd
       or  die "Can't fdup STDERR: $!";
    
    return $error;
}

sub _generate_emitter {
    my ( $self ) = @_;
    my $handle      = $self->[DUP_HANDLE];
    my $level       = $self->[LEVEL];
    my $dup         = $self->[DUP];
    my $event_class   = $self->[CLASS];
    my $event_config  = $self->[CONFIG];
    $event_class = Log::Lager::_load_event_class({ $event_class, $event_config })
        if $event_class;

    my $context = 0;
    my $level_handler =  Log::Lager->can($level)
        or die "Invalid log level '$level'\n";

    my $code =        "sub {\n";
    $code .=          "    syswrite( \$handle, \$_[0] );\n"
        if $dup;
    $code .= $event_class
        ? join( "\n", "    Log::Lager->log_from_context( '$level', $context,  ",
                      "      $event_class->new( ",
                      "        context=> 1+$context, body => [\@_],",
                      "        \@\$event_config,  ",
                      "      )",
                      "    );",''
        )
        : join( "\n", "    Log::Lager->log_from_context( '$level', $context,  ",
                      "      $Log::Lager::EVENT_CLASS->new( ",
                      "        context=> 1+$context, body => [\@_]",
                      "      )",
                      "    );",'',
        );
    $code .=          "} ";

    my $emit = eval $code
        or do {
            my $e = $@ || 'Unknown error';
            die "Error compiling capture emitter - $e\n";
        };
    return $emit;
}

{   package Log::Lager::Capture::_impl;
    use strict;
    use warnings;
    use Log::Lager::Component;

    $Carp::Internal{__PACKAGE__}++;
    our @ISA = qw< Tie::Handle >;


    # handle, dup, emitter
    sub TIEHANDLE {
        my ($class, $emitter) = @_;

        my $self = bless $emitter, ref $class || $class;

        return $self;
    }

    sub WRITE {
        my( $self, undef, $len, $offset ) = @_; 
        my $sv_buf = \$_[1]; # Don't copy buffer


        our $RECURSION_TRAP;  
        return if $RECURSION_TRAP;
        local $RECURSION_TRAP = 1;

        local *STDERR = $Log::Lager::STDERR;
        $len //= ''; 

        if( $offset ) { 
            my $buf = '' eq $len
                ?   substr( $$sv_buf, $offset )
                :   substr( $$sv_buf, $offset, $len )
                ;   

            $sv_buf = \$buf;
        } elsif( 
            '' ne $len
            && $len != length($$sv_buf)
        ) { 
            my $buf = substr( $$sv_buf, 0, $len );
            $sv_buf = \$buf;
        }

        $self->( $$sv_buf );       # Log data to selected log
    }

}


__PACKAGE__;
