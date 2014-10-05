use Test::More;
use strict; use warnings FATAL => 'all';

use Text::ZPL;

## Encoding failures
# unrepresentable list items
eval {; encode_zpl(+{ list => [ 'a', b => [1..3] ] }) };
like $@, qr/structure.*list/, 'encode deeply-nested items in lists dies';

# bad property/section names
eval {; encode_zpl(+{ 'a%b' => 1 }) };
like $@, qr/property.name/, 'encode bad property name dies';
eval {; encode_zpl(+{ 'a%b' => +{a => 1}}) };
like $@, qr/property.name/, 'encode bad section name dies';

my $s = \'';
eval {; encode_zpl(+{ a => $s }) };
like $@, qr/handle/, 'encode unknown ref type dies';


# Decoding failures
# bad subsect name
my $zpl = <<'BADSECT';
fo%o
    bar = 1
BADSECT
eval {; decode_zpl($zpl) };
like $@, qr/syntax/, 'bad section name dies';

# bad property name
$zpl = <<'BADPROP';
foo
    b%ar = 1
BADPROP
eval {; decode_zpl($zpl) };
like $@, qr/property.name/, 'bad property name dies';

# bad indent (not 4-sp)
$zpl = <<'NOTFOUR';
foo
  bar = 1
NOTFOUR
eval {; decode_zpl($zpl) };
like $@, qr/indent/, 'invalid indent level dies';

# bad indent (no parent)
$zpl = <<'NOPARENT';
foo
    bar = 1
        baz = 2
NOPARENT
eval {; decode_zpl($zpl) };
like $@, qr/parent/, 'missing parent dies';

done_testing
