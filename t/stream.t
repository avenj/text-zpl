use Test::More;
use strict; use warnings FATAL => 'all';

use Text::ZPL::Stream;

my $zpl = do { local $/; <DATA> };

my $expected = +{
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

  emptysection => +{},

  other => +{
    list => [
      'foo bar', 'baz quux', 'weeble'
    ],
    deeper => +{
      list2 => [ 123, 456 ],
    },
  }
};


# One arg, two chars per:
{
  my $stream = Text::ZPL::Stream->new;
  no warnings 'substr';
  my $tmp = $zpl;
  while (length $tmp) {
    my $chrs = substr $tmp, 0, 2, '';
    $stream->push($chrs);
  }
  is_deeply $stream->get, $expected,
    'one arg push w/ two chars per ok'
      or diag explain $stream;
}



done_testing;

__DATA__
toplevel = 123
quoted   = "foo bar"
unmatched = "foo'
# There's a comment here
# and here

context #
    iothreads = 1   # With trailing comment
    verbose   = 1 #

main                # Section head with trailing comment
    type = zmq_queue
    frontend
        option
            hwm  = 1000
            swap = 25000000
            subscribe = "#2"
        bind = tcp://eth0:5555
    backend
        bind = tcp://eth0:5556

emptysection

other
    list = "foo bar"
    list = 'baz quux'  #
    list = weeble
    deeper
        list2 = 123
        list2 = 456
