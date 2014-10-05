use Test::More;
use strict; use warnings FATAL => 'all';

use Text::ZPL;

# Encoding failures
eval {; encode_zpl(+{ list => [ 'a', b => [1..3] ] }) };
like $@, qr/structure.*list/, 'encode deeply-nested items in lists dies';

eval {; encode_zpl(+{ 'a%b' => 1 }) };
like $@, qr/property.name/, 'encode bad property name dies';

my $s = \'';
eval {; encode_zpl(+{ a => $s }) };
like $@, qr/handle/, 'encode unknown ref type dies';


# Decoding failures
# FIXME set up a series of t/inc/*.zpl files representing failure types:
#   - bad subsect names
#   - bad property names
#   - bad indenting, missing section head + related
#   ...


done_testing
