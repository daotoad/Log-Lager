package Log::Lager::CommandParser;
BEGIN {
  $Log::Lager::CommandParser::VERSION = '0.04.06';
}
use strict;
use warnings;
use Carp qw<croak>;
use Data::Dumper;

use Scalar::Util qw< blessed >;
use Hash::Util  qw< lock_keys >;

use Exporter qw( import );
our @EXPORT_OK = qw( parse_command Log::Lager::Command::REWIND );

sub new {

    my $self = {
        state            => 'start',
        result           => Log::Lager::CommandResult->new(),
        mask_select      => 'lexical',
        mask_group       => 'enable',
        mask             => undef,
        output           => 'stderr',
        state_table      => \%Log::Lager::Command::STATE_TABLE,
        end_states       => \%Log::Lager::Command::END_STATES,
    };

    bless $self;
    lock_keys %$self;

    return $self;
}

# Basic, vanilla accessors.
sub state            { my $self = shift; $self->{state} = shift if @_;            $self->{state}            }
sub result           { my $self = shift; $self->{result} = shift if @_;           $self->{result}           }
sub mask_select      { my $self = shift; $self->{mask_select} = shift if @_;      $self->{mask_select}      }
sub mask_group       { my $self = shift; $self->{mask_group} = shift if @_;       $self->{mask_group}       }
sub mask             { my $self = shift; $self->{mask} = shift if @_;             $self->{mask}             }
sub state_table      { my $self = shift;                                          $self->{state_table}      }

sub end_state        { my $self = shift;
    my $state = @_ ? shift : $self->state;
    return exists $self->{end_states}{$state};
}

# Set the mask based on the values in mask_select
sub select_mask {
    my $self = shift;

    my $method = $self->mask_select;
    $self->mask( $self->result->$method(@_) );
}

sub set_mask_to {
    my $self = shift;

    my $method = $self->mask_group;
    $self->mask->$method(@_);
}


sub parse_command {
    my $self = blessed $_[0] ? shift : __PACKAGE__->new();

    my @tokens = $self->tokenize(@_);

    return $self->parse(@tokens);
}

sub tokenize {
    my $self = shift;
    return split /\s+/, join ' ', grep defined $_, @_;
}


sub parse {
    my $self = shift;
    my @tokens = @_;

    my $state;
    my $STATE_TABLE = $self->state_table;

STATE:
    while ( $state = $self->state or defined $state ) {
        my $next = shift @tokens;

        #warn "Next is $next\n" if defined $next;;

        if( not defined $next and $self->end_state ) {
            my $base = $self->result->base;
            $base->complete if $base->changed;
            return $self->result
        }

        croak "Parse error: out of tokens in non-end-state '$state'"
            unless $next;

        croak "State '$state' is not defined"
            unless exists $STATE_TABLE->{$state};

TEST:
        for my $test ( @{ $STATE_TABLE->{$state} } ) {
            my ($match, $do, $go) = @$test;

            local $_ = $next;

            if ( not defined $match or $self->$match() ) {

                my $done = $do->($self); $done = '' unless defined $done;

                if( defined $do and  $done eq 'REWIND' ) {
                    unshift @tokens, $next;
                }

                $state = defined $go && ref $go ? $go->() : $go;

                $self->state($state);
                next STATE;
            }

        }

        croak "No match for '$next' in  $state - @_";
        $self->state(undef);
    }

    croak "Parse error: Unexpected parser state: @tokens";
}




BEGIN {
    package Log::Lager::CommandResult;
BEGIN {
  $Log::Lager::CommandResult::VERSION = '0.04.06';
}
    use overload '""' => 'as_string';

    sub new {
        my $class = shift;

        my $self = {
            lexical          => Log::Lager::Mask->new(),
            base             => Log::Lager::Mask->new(),
            package          => {},
            sub              => {},
            syslog_identity  => undef,
            syslog_facility  => undef,
            file_name        => undef,
            file_perm        => undef,
            output           => undef,
            lexicals_enabled => undef,
            message_object   => undef,
        };

        bless $self, $class;

        return $self;
    }

    sub lexical { my $self = shift; $self->{lexical} };
    sub base    { my $self = shift; $self->{base}    };
    sub lexicals_enabled { my $self = shift; $self->{lexicals_enabled} = shift if @_; $self->{lexicals_enabled} }
    sub syslog_facility  { my $self = shift; $self->{syslog_facility}  = shift if @_; $self->{syslog_facility}  }
    sub syslog_identity  { my $self = shift; $self->{syslog_identity}  = shift if @_; $self->{syslog_identity}  }
    sub file_name        { my $self = shift; $self->{file_name} = shift if @_;        $self->{file_name}        }
    sub file_perm        { my $self = shift; $self->{file_perm} = shift if @_;        $self->{file_perm}        }
    sub output           { my $self = shift; $self->{output} = shift if @_;           $self->{output}           }
    sub message_object   { my $self = shift; $self->{message_object} = shift if @_;   $self->{message_object} }

    sub package_names {
        my $self = shift;

        return sort keys %{$self->{package} || {}}
    }

    sub read_package {
        my $self = shift;
        my $name = shift;

        return unless exists $self->{package}{$name};
        return $self->{package}{$name};
    }

    # Use fully qualified name since 'package' is a Perl keyword.
    # This sucks a bit, but it makes it easy to map between language
    # keywords and method names.
    sub Log::Lager::CommandResult::package {
        my $self = shift;
        my $name = shift;

        $self->{package}{$name} = Log::Lager::Mask->new();

        return $self->{package}{$name};
    }

    sub sub_names {
        my $self = shift;

        return sort keys %{$self->{sub} || {}};
    }

    sub read_sub {
        my $self = shift;
        my $name = shift;

        return unless exists $self->{sub}{$name};
        return $self->{sub}{$name}
    }

    # Use fully qualified name since 'sub' is a Perl keyword.
    # This sucks a bit, but it makes it easy to map between language
    # keywords and method names.
    sub Log::Lager::CommandResult::sub {
        my $self = shift;
        my $name = shift;

        $self->{sub}{$name} = Log::Lager::Mask->new();

        return $self->{sub}{$name};
    }

    sub as_string {
        my $self = shift;

        my @sub_masks     = map "$_ $self->{sub}{$_}",     $self->sub_names;
        my @package_masks = map "$_ $self->{package}{$_}", $self->package_names;
        my $mask_string = join ' ',
            lexical   => $self->lexical,
            base      => $self->base,
            ( @sub_masks     ? ('sub'     => @sub_masks)     : () ),
            ( @package_masks ? ('package' => @package_masks) : () );

        my $output = $self->output;
        my $out_string = ! defined $output ? ''
                       : $output eq 'file'   ?  join(' ', 'file', $self->file_name,
                                                          ( defined $self->file_perm
                                                            ? ( fileperm => $self->file_perm )
                                                            : ()
                                                          )
                                                    )
                       : $output eq 'syslog' ?  join(' ', 'syslog', $self->syslog_identity, $self->syslog_facility)
                       : 'stderr';

        my $lexon_string = $self->lexicals_enabled ? 'lexon' : 'lexoff';

        my $message_object = $self->message_object;
        $message_object = 'Log::Lager::Message'
            unless defined $message_object;

        $message_object = "message $message_object";

        my $string = join ' ', grep length, $mask_string,  $out_string, 
                                            $lexon_string, $message_object;

        return $string;
    }
}

BEGIN {
    package Log::Lager::Mask;
BEGIN {
  $Log::Lager::Mask::VERSION = '0.04.06';
}
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


    sub new {
        my $class = shift;

        my $self = {};

        bless $self, $class;

        return $self;
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

    sub enable {
        my $self = shift;
        $self->toggle_mask( enable => disable => @_ );
    }

    sub disable {
        my $self = shift;
        $self->toggle_mask( disable => enable => @_ );
    }

    sub pretty {
        my $self = shift;
        $self->toggle_mask( pretty => compact => @_ );
    }

    sub compact {
        my $self = shift;
        $self->toggle_mask( compact => pretty => @_ );
    }

    sub stack {
        my $self = shift;
        $self->toggle_mask( stack => nostack => @_ );
    }

    sub nostack {
        my $self = shift;
        $self->toggle_mask( nostack => stack => @_ );
    }

    sub fatal {
        my $self = shift;
        $self->toggle_mask( nonfatal => fatal => @_ );
    }

    sub nonfatal {
        my $self = shift;
        $self->toggle_mask( fatal => nonfatal => @_ );
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

}


BEGIN {
    package Log::Lager::Command;
BEGIN {
  $Log::Lager::Command::VERSION = '0.04.06';
}

=pod

command_string -> command_group ( \s* command_group )
command_group  -> ( mask_control | lex_control | output_control | message_config )
mask_control   -> mask_selector ( \s mask_group ( \s mask_set )* )*
mask_selector  -> ( lexical | base | package \s  name | sub \s  name )
mask_group     -> ( enable | disable | pretty | compact | stack | nostack | fatal | nonfatal )
mask_set       -> [FEWIDTG]*
name           -> ( \w | :: )+
lex_control    -> ( lexon | lexoff )
output_control -> ( stderr | file_spec | syslog_spec )
file_spec      -> file \s+ file_name \s+ ( on|off)
file_name      -> [\w\/]
syslog_spec    -> syslog \s+ (syslog_conf | off )
message_config -> message \s+ (Some::Module::Name)

=cut

# The state table defines a set of named states.  Each state consists of an
# array of test definitions that dictate the state's behavior.
#
# Each test definition consists of a 3 element tuple featuring the match
# condition, the state action, and the next state.
#
# The match condition may be a code ref or undefined.  If undefined, the match
# always succeeds.  Otherwise, the code reference is called and the return
# value is evaluated in boolean context.  On a true result, testing stops,
# and the other values in the test definition are inspected and acted upon.
# On a false result we move to the next test definition.
#
# When a match condition returns true, we evaluate the action.  The action may
# be a code ref or undef.  Undef indicates a no-op.  If the action is a code ref,
# the code is called.
#
# After the action is completed, we set the state to it new value.  
    our %STATE_TABLE = (
    #   name       # Array of match/action/transition tuples
        start => [
           # Match Condition         Action                   Next State
           # If true                 do this                  and go here
           [ \&match_mask_selector,  \&select_bl_mask,        \&get_mask_state       ],
           [ \&match_lex_control,    \&config_lex,            'start'                ],
           [ \&match_output_control, \&select_output_mode,    \&get_output_state     ],
           [ \&match_message_config, \&select_message_config, 'want_message_package' ],
        ],

        want_filename => [
            [ \&match_filename,      \&set_file_out,        'start'                 ],
        ],

        want_fileperm => [
            [ \&match_fileperm,      \&set_file_perm,       'start'                 ],
        ],

        want_syslog_ident => [
            [ \&match_filename,       \&set_syslog_ident,    'want_syslog_facility' ],
        ],

        want_syslog_facility => [
            [ \&match_filename,       \&set_syslog_facility, 'start'                ],
        ],

        want_mask_sub => [
            [ \&match_package_or_sub, \&select_sub_mask,     'mask_selected'        ],
        ],

        want_mask_package => [
            [ \&match_package_or_sub, \&select_package_mask, 'mask_selected'        ],
        ],

        want_message_package => [
            [ \&match_message_package, \&set_message_package, 'start'        ],
        ],

        mask_selected => [
            [ \&match_mask_group,     \&select_mask_group,   'want_mask_chars'      ],
            [ \&match_mask_chars,     \&set_mask,            'want_mask_chars'      ],
            [ undef,                  \&REWIND,              'start'                ],
        ],

        want_mask_chars => [
            [ \&match_mask_chars,     \&set_mask,            'want_mask_chars'      ],
            [ undef,                  \&REWIND,              'mask_selected'        ],
        ],

    );
    my @END_STATES = qw( start want_mask_chars mask_selected  );
    our %END_STATES; @END_STATES{@END_STATES} = ();

    sub REWIND() { 'REWIND' };

    sub match_mask_selector { /lexical|base|package|sub/ }
    sub select_bl_mask {
        my $cp = shift;

        $cp->mask_select($_);
        return unless /lexical|base/;

        $cp->select_mask;
        return;
    }

    sub get_mask_state {
        return /lexical|base/ ? 'mask_selected'
             : /package/      ? 'want_mask_package'
             : /sub/          ? 'want_mask_sub'
             : undef;
    }

    sub match_lex_control { /lexon|lexoff/ }
    sub config_lex {
        my $cp = shift;

        $cp->result->lexicals_enabled($_ eq 'lexon' ? 1 : 0 );
        return;
    }

    sub match_output_control { /stderr|syslog|file|fileperm/ }
    sub select_output_mode {
        my $cp = shift;
        return if $_ eq 'fileperm';
        $cp->result->output($_);
        return;
    }
    sub get_output_state {
        return /stderr/   ? 'start'
             : /syslog/   ? 'want_syslog_ident'
             : /file/     ? 'want_filename'
             : /fileperm/ ? 'want_fileperm'
             : undef;
    }


    sub match_package_or_sub { /^(?:\w|::)+/ }
    sub select_sub_mask {
        my $cp = shift;
        $cp->select_mask($_);
        return;
    }

    sub select_package_mask {
        my $cp = shift;
        $cp->select_mask($_);
        return;
    }

    sub match_mask_group { /^($Log::Lager::Mask::GROUP_REGEX)$/ }
    sub select_mask_group {
        my $cp = shift;
        $cp->mask_group($_);
        return;
    }

    sub match_mask_chars { /^[$Log::Lager::Mask::MASK_REGEX]+$/ }
    sub set_mask {
        my $cp = shift;
        $cp->set_mask_to($_);
        return;
    }

    sub match_filename { /^[\w.\/-]+$/ }
    sub set_file_out {
        my $cp = shift;
        $cp->result->file_name($_);
        return;
    }

    sub match_fileperm { /^[0-8][0-8][0-8]+$/ }
    sub set_file_perm {
        my $cp = shift;
        $cp->result->file_perm($_);
        return;
    }

    sub set_syslog_ident {
        my $cp = shift;
        $cp->result->syslog_identity( $_ );
        return;
    }

    sub set_syslog_facility {
        my $cp = shift;
        $cp->result->syslog_facility( $_ );
        return;
    }

    sub match_message_config { /^message$/ }
    sub match_message_package { /^(?:\w+|::)+$/ }
    sub select_message_config { };
    sub set_message_package {
        my $cp = shift;
        $cp->result->message_object( $_ );
        return;
    }

}
1;

=for Pod::Coverage end_state mask mask_group mask_select new parse parse_command result select_mask set_mask_to state state_table tokenize


=head1 NAME

Log::Lager::CommandParser

=head1 VERSION

version 0.04.06

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
 base             - The lexical logging mask. A C<Log::Lager::Mask> object.
 package          - Package logging masks defined in this command. A hash ref of C<Log::Lager::Mask> objects, keyed by package name.
 sub              - Subroutine logging masks defined in this command. A hash ref of C<Log::Lager::Mask> objects, keyed by subroutine name.
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