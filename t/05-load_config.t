use Test::More tests => 6;

use strict;
use warnings;

use File::Temp;

use_ok( 'Log::Lager' ) or BAIL_OUT( "Module under test failed to load." );

use Log::Lager 'FEWIDTGU';

{  # Default conditions.
    my $log_level =  Log::Lager::log_level();
    SKIP: {
        skip "Ancient Perl's lexicality is limited.", 1 if $] < 5.009;
        like( $log_level->{lexical}, qr/enable FEWIDTGU/,  'Lexical settings correct'      );
    }
    like( $log_level->{base}, qr/enable FEW disable IDTGU/, 'Default base settings correct' );
}


my $cfgh = File::Temp->new();
my $cfg_name = $cfgh->filename;

write_config_file( $cfg_name, <<'CFG' );
{   "levels" : {
        "base": "enable FEWI nonfatal FEWIDTGU compact FEWIDTGU"
    },
    "lexical_control" : true
}

END
CFG


{   #Config from file

    Log::Lager::load_config({ File => { file_name => $cfg_name}});
    my $log_level =  Log::Lager::log_level();
    like( $log_level->{base}, qr/enable FEWI disable DTGU/, 'Base settings updated' );
}

write_config_file( $cfg_name, <<'CFG' );

{   "levels" : {
        "base" : "enable FEWID fatal FEWU nonfatal IDTG compact  FEWIDTGU nostack FEWIDTGU"
    },
    "lexical_control" : false
}

END



CFG

{   #Config from file

    Log::Lager::load_config();
    my $log_level =  Log::Lager::log_level();
    like( $log_level->{base}, qr/enable FEWID disable TGU/, 'Base settings enable updated' );
    like( $log_level->{base}, qr/fatal FEWU nonfatal IDTG/, 'Base settings fatal updated'  );

}

sub write_config_file {
    my $name =  shift;
    my $fh;
    open($fh, ">", $name) or die "Couldn't write to config file: $!\n";
    print $fh @_;
    close $fh;
}

