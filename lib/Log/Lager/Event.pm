package Log::Lager::Event;
use strict;
use warnings;
use Carp            qw<croak>;
use Config          qw< %Config >;
use POSIX           qw< strftime >;
use Time::Hires     qw<>;
use Data::Abridge   qw< abridge_recursive >;
use Scalar::Util    qw< blessed >;

use Log::Lager::Component;
use Log::Lager::Context;
use Log::Lager::Format;


use constant DEFAULT_HEADER_FIELDS => qw(
    timestamp
    log_level
    host_name
    executable
    process_id
    thread_id
    file_name
    line_number
    package
    subroutine
);

use constant DEFAULT_TEMPLATE => [ [DEFAULT_HEADER_FIELDS], 'body', 'stack' ];


use constant DEFAULT_TIMESTAMP_FORMAT => '%Y-%m-%dT%H:%M:%S.%3NZ';


sub new {
    my ($class, %opt) = @_;

    my $body = delete $opt{body} || [];
    $body = [$body] unless ref $body eq 'ARRAY';


    my $self = {
        epoch               => Time::HiRes::time(),
        log_level           => delete $opt{log_level},
        context             => delete $opt{context} || 0,
        body                => $body,
        on_log              => delete $opt{on_log},
        on_fatal            => delete $opt{on_fatal},

        return_result       => delete $opt{return_result} || [],
        return_wantarray    => delete $opt{return_wantarray},
        return_exception    => delete $opt{return_exception},

        extract_template    => delete $opt{extract_template}
                                || $class->DEFAULT_TEMPLATE,
        timestamp_format    => delete $opt{timestamp_format}
                                || $class->DEFAULT_TIMESTAMP_FORMAT,

        will_log            => delete $opt{will_log},
        will_die            => delete $opt{will_die},
        expanded            => delete $opt{expanded},
        process_id          => delete $opt{process_id},
        thread_id           => delete $opt{thread_id},
        host_name           => delete $opt{host_name},
        timestamp           => delete $opt{timestamp},
        executable          => delete $opt{executable},
        file_name           => delete $opt{file_name},
        package             => delete $opt{package},
        line_number         => delete $opt{line_number},
        subroutine          => delete $opt{subroutine},

        formatter           => delete $opt{formatter}
                                || Log::Lager::Format::JSON->new(),
        formatted           => undef,
        extracted           => undef,
    };

    # TODO  -  die here on leftover %opt

    bless $self, $class;

    $self->get_context();

    return $self;
}

sub get_context {
    my ($self) = @_;

    my $c = $self->{context};

    return $c
        if defined $c
        && ref $c;

    $self->{context} = Log::Lager::Context->new($c);

    return $self->{context};
}

sub populate {
    my ($self, %opt) = @_;
    
    # Short circuit processing if we are not logging this.
    my $will_log    = delete $opt{will_log}
        or return $self;
    my $will_die    = delete $opt{will_die};
    my $want_stack  = delete $opt{want_stack};
    my $expanded    = delete $opt{expanded};
    

    my $ctxt = $self->get_context();
    my ($pi_exec, $pi_host, $pi_pid, $pi_thread)
        = $ctxt->ProcessInfo();

    my $pid        = delete $opt{pid} || $pi_pid;
    my $thread_id  = delete $opt{thread_id} // $pi_thread;
    my $host       = delete $opt{host} || $pi_host;
    my $exec       = delete $opt{exec} || $pi_exec;
    my $log_level   = delete $opt{log_level};

    my %context = $ctxt->AsHash();
    my $file_name   = $context{file};
    my $package     = $context{package};
    my $subroutine  = $context{sub};
    my $line_number = $context{line};

    my $stack = $want_stack
        ? $ctxt->StackTrace()
        : undef;

    # Populate unset values.
    $self->{process_id}     //= $pid;
    $self->{executable}     ||= $exec;
    $self->{thread_id}      //= $thread_id;
    $self->{host_name}      ||= $host;
    $self->{timestamp}      ||= $self->_format_timestamp();
    $self->{will_log}       //= $will_log;
    $self->{will_die}       //= $will_die;
    $self->{expanded}       //= $expanded;
    $self->{stack}          ||= $stack;
    $self->{file_name}      ||= $file_name;
    $self->{package}        ||= $package;
    $self->{subroutine}     ||= $subroutine;
    $self->{line_number}    ||= $line_number;
    $self->{log_level}      //= $log_level;

    $self = $self->_exec_log();
    $self = $self->_exec_fatal();

    $self->extract();
    my $formatted = $self->format();

    $self->{return_exception} ||= $formatted
        if $self->{will_die};

    return $self;
}

sub finalize {
    my ($self) = @_;

}

sub _format_timestamp {
    my ($self) = @_;

    my $template = $self->{timestamp_format};
    my $epoch = $self->{epoch};
    my $nanosecs = $epoch - int $epoch;

    # Extend POSIX::strftime to handle %N extension
    $template =~ s[%(\d*)?N][
        my $places = defined $1 ? $1 : 9;
        my $t = sprintf "%0.${places}f", $nanosecs;
        $t =~ s/^0\.//;
        $t;
    ]ex;
    
    my $formatted = POSIX::strftime( $template, POSIX::gmtime($epoch) );

    return $formatted;
}

sub _exec_log {
    my ($self) = @_;
    return $self
        unless $self->{will_log};
    return $self->_exec( $self->{on_log} );
}

sub _exec_fatal {
    my ($self) = @_;
    return $self
        unless $self->{will_die};
    return $self->_exec( $self->{on_fatal} );
}

sub _exec {
    my ($self, $code) = @_;

    return $self unless $code;

    my @results = $code->($self);

    # replace $self with object returned
    if ( 1 == @results && eval { $results[0]->isa('Log::Lager::Event')  } ) {
        $self = $results[0];
        return $self;
    }

    push @{$self->{body}}, @results;

    return $self;
}

sub _recursive_extract {
    my ($self, $template) = @_;

    my $type = ref $template;

    return $type eq 'ARRAY' ? $self->_extract_array($template)
        :  $type eq 'HASH'  ? $self->_extract_hash($template)
        :                     $self->_extract_scalar($template);
}

sub _extract_array {
    my ($self, $template) = @_;

    return [ map $self->_recursive_extract($_), @$template ];
}

sub _extract_hash {
    my ($self, $template) = @_;

    my %extracted;
    @extracted{ keys %$template } = map $self->_recursive_extract($_), values %$template;

    return \%extracted;
}

sub _extract_scalar {
    my ($self, $template) = @_;
    my $string = "$template";

    return
        if $string eq 'stack'
        && !$self->{want_stack};

    return @{ $self->{body} }
        if $string eq 'body';

    return exists $self->{$string} ? $self->get($string)
        :  croak "Invalid item '$string' in event template";
}


sub extract {
    my ($self) = @_;

    my $template = $self->{extract_template};
    my $extracted = $self->_recursive_extract($template);


    $extracted = abridge_recursive( $extracted );

    $self->{extracted} = $extracted;
    return $extracted;
}

sub format {
    my ($self) = @_;

    return
        unless $self->{will_log};

    return $self->{formatted}
        if defined $self->{formatted};

    my $formatter = blessed($self->{formatter}) && $self->{formatter}->isa('Log::Lager::Format')
            ? $self->{formatter}
            : do {
                my ($f_class, @f_opt) = @{$self->{formatter}};
                my $f = $f_class->new( @f_opt );
            };

    my $formatted = $formatter->format( $self );
    $self->{formatted} = $formatted;

    return $formatted;
}

sub will_log {
    my ($self) = @_;
    return !!$self->{will_log};
}

sub will_die {
    my ($self) = @_;
    return !!$self->{will_die};
}

sub want_expanded_format {
    my ($self) = @_;
    return !!$self->{expanded};
}

sub return_result {
    my ($self) = @_;
    return @{$self->{return_result}};
}

sub return_exception {
    my ($self) = @_;
    return $self->{return_exception};
}

sub get {
    my ($self, @fields) = @_;

    my $bad = join',',
        map "'$_'",
        grep ! exists $self->{$_},
        @fields;
    croak "Illegal fields in event data request - $bad"
        if $bad;

    my @result = map $self->{$_}, @fields;

    return wantarray ? @result : $result[0];
}

# TODO - put some safeties on this
#   Are there any values we want to prevent editing?
sub set {
    my ($self, %fields) = @_;

    my $bad = join',',
        map "'$_'",
        grep ! exists $self->{$_},
        keys %fields;
    croak "Illegal fields in event data request - $bad"
        if $bad;

    @{$self}{keys %fields} = values %fields;

    return;
}

sub get_hash {
    my ($self, @fields) = @_;

    my %result;
    @result{@fields} = self->get( @fields ); 

    return %result;
}

sub set_return {
    my ($self, %opt) = @_;

    if ( exists $opt{result} ) {
        my $result = $opt{result};

        $self->{return_result} = ref $result eq 'ARRAY' ? $result : [ $result ];
    }
    if ( exists $opt{wantarray} ) {
        $self->{return_wantarray} = $opt{return_wantarray};
    }
    if ( exists $opt{exception} ) {
        $self->{return_exception} = $opt{return_exception};
    }
    
    return;
}

1;
__END__

=head1 NAME

Log::Lager::Event

=head1 SYNOPSIS


=head1 DESCRIPTION

Collect data for a Log::Lager log entry.

=head1 EXTENDING

=head2 Changing Defaults

=head3 Date/Time Formatting

DEFAULT_TIMESTAMP_FORMAT

=head3 Event Sections

    DEFAULT_HEADER_FIELDS
    DEFAULT_STACK_FIELDS
    DEFAULT_FOOTER_FIELDS

=head2 Adding Sections

    extract
    _extract_*

=head2 Adding Fields

    Add more attributes to object

=head1 SUBCLASSING

=head2 Object internals

    basic, flat, blessed hash.

    1-1 relationship between attributes and fields

=head2 Log::Lager registration

    use Log::Lager::Component;

    - or -

    use Log::Lager::InlineClass;


=head2 Constructors

Unpack your arguments before calling parent constructor, it will die
on contact with unexpected arguments.

    sub new {
        my ($class, %opt) = @_;

        my $new_field = delete $opt{new_field};

        my $self = $class->PARENT::new(%opt);

        $self->{new_field} = $new_field;
        
        return $self;
    }


