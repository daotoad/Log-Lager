use Test::More tests => 6;

use strict;
use warnings;

use File::Temp;

use_ok( 'Log::Lager' ) or BAIL_OUT( "Module under test failed to load." );

use Log::Lager 'FEWIDTGU';

{  # Default conditions.
    my $log_level =  Log::Lager::log_level();
SKIP: {
        skip 'Ancient Perl\'s lexicality is limited.' if $] < 5.009;
        like( $log_level, qr/lexical enable FEWIDTGU/,       'Lexical settings correct'      );
    }
    like( $log_level, qr/base enable FEW disable IDTGU/, 'Default base settings correct' );
}


my $cfgh = File::Temp->new();
my $cfg_name = $cfgh->filename;

write_config_file( $cfgh, <<'CFG' );
base enable FEWI
nonfatal FEWIDTGU
compact FEWIDTGU
lexoff

END
CFG


{   #Config from file

    Log::Lager::load_config_file( $cfg_name );
    my $log_level =  Log::Lager::log_level();
    like( $log_level, qr/base enable FEWI disable DTGU/, 'Base settings updated' );

    warn $log_level;
}

write_config_file( $cfgh, <<'CFG' );
base enable   FEWID
     fatal    FEWU
     nonfatal IDTG
     compact  FEWIDTGU
     nostack  FEWIDTGU
lexoff

END
CFG

{   #Config from file

    Log::Lager::load_config_file();
    my $log_level =  Log::Lager::log_level();
    like( $log_level, qr/base enable FEWID disable TGU/, 'Base settings enable updated' );
    like( $log_level, qr/fatal FEWU nonfatal IDTG/,      'Base settings fatal updated'  );

    warn $log_level;
}

sub write_config_file {
    my $fh =  shift;
    $fh->seek( 0, 0 );
    $fh->printflush( @_ );
}

