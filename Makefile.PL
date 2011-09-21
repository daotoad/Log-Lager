
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Easy to use, flexible, parsable logs.",
  "AUTHOR" => "Mark Swayne <daotoad\@cpan.org>",
  "BUILD_REQUIRES" => {
    "File::Temp" => 0,
    "JSON" => 0,
    "Test::More" => 0,
    "base" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Log-Lager",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Log::Lager",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Config" => 0,
    "Data::Abridge" => 0,
    "Data::Dumper" => 0,
    "Exporter" => 0,
    "Hash::Util" => 0,
    "IO::File" => 0,
    "IO::Handle" => 0,
    "JSON::XS" => 0,
    "Scalar::Util" => 0,
    "Sys::Hostname" => 0,
    "Sys::Syslog" => 0,
    "Time::HiRes" => 0,
    "constant" => 0,
    "overload" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.04.05",
  "test" => {
    "TESTS" => "t/*.t t/CommandParser/*.t t/Message/*.t"
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



