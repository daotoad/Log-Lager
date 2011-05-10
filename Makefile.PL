
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Easy to use, flexible, parsable logs.',
  'AUTHOR' => 'Mark Swayne <daotoad@cpan.org>',
  'BUILD_REQUIRES' => {
    'Test::More' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.30'
  },
  'DISTNAME' => 'Log-Lager',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Log::Lager',
  'PREREQ_PM' => {
    'Carp' => '0',
    'Data::Abridge' => '0',
    'Data::Dumper' => '0',
    'Exporter' => '0',
    'Hash::Util' => '0',
    'IO::File' => '0',
    'Scalar::Util' => '0',
    'Sys::Syslog' => '0',
    'constant' => '0',
    'overload' => '0'
  },
  'VERSION' => '0.02',
  'test' => {
    'TESTS' => 't/*.t t/CommandParser/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



