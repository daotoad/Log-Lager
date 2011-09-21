package Log::Lager::ConfigFile;
BEGIN {
  $Log::Lager::ConfigFile::VERSION = '0.04.06';
}

use strict;
use warnings;

=head1 NAME

Log::Lager::ConfigFile

=head1 VERSION

version 0.04.06

=head1 SYNOPSIS

Config File Format

JSON

Objects 

{   "logging" : {
        "enable" : 'FEWTIGUD',
        stack : FEWTIDGU
        pretty : FEWTIDGU
        compact: 
        lexical_controls: 'true' / 'false'
        message: 'LLM',
        output:  'stderr',
    },
    message : {
    },
    stderr : {
    },
    syslog : {
    },
    file : {
    },

        class : 'LLE::Stderr',  <-- default
                'LLE::Syslog',
                'LLE::File',   
    }