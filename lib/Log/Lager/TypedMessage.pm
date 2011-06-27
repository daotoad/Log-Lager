package Log::Lager::TypedMessage;
use strict;
use warnings;
use Carp qw<croak>;


sub new {
      my $class = shift;
      my $type = shift;
      my @messages = @_;

      return bless [ $type, @messages ], $class;
}

1;


=head1 NAME

Log::Lager::TypedMessage

=head1 SYNOPSIS

Provides a way to override normal Log::Lager output conventions.

Should be used by libraries that want to work with Log::Lager rather than by end users.



