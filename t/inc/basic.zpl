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

other
    list = "foo bar"
    list = 'baz quux'  #
    list = weeble
    deeper
        list2 = 123
        list2 = 456
