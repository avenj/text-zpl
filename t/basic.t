use Test::More;
use strict; use warnings FATAL => 'all';

use Path::Tiny;


use Text::ZPL;


my $basic = path("t/inc/basic.zpl")->slurp;

my $data = decode_zpl($basic);
is_deeply $data,
  +{
    toplevel  => 123,
    quoted    => 'foo bar',
    unmatched => q{"foo'},

    context => +{
      iothreads => 1,
      verbose   => 1,
    },

    main => +{
      type => 'zmq_queue',
      frontend => +{
        option => +{
          hwm  => 1000,
          swap => '25000000',
          subscribe => '#2',
        },
        bind => 'tcp://eth0:5555',
      },
      backend => +{
        bind => 'tcp://eth0:5556',
      },
    },

    other => +{
      list => [
        'foo bar', 'baz quux', 'weeble'
      ],
      deeper => +{
        list2 => [ 123, 456 ],
      },
    },
  },
  'decode_zpl ok';

my $reencoded = encode_zpl $data;

my $roundtripped = decode_zpl $reencoded;
is_deeply $roundtripped, $data, 'roundtripped ok';


done_testing
