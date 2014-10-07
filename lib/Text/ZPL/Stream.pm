package Text::ZPL::Stream;

use strict; use warnings FATAL => 'all';
use Carp;

use Text::ZPL ();


sub BUF_MAX         () { 0 }
sub BUF             () { 1 }
sub MAYBE_EXTRA_EOL () { 2 }
sub ROOT            () { 3 }
sub CURRENT         () { 4 }
sub LEVEL           () { 5 }
sub TREE            () { 6 }

sub new {
  #  max_buffer_size =>
  #  string =>
  my ($class, %param) = @_;
  my $root = +{};
  my $self = bless [
    ($param{max_buffer_size} || 0),  # BUF_MAX
    '',                              # BUF
    0,                               # MAYBE_EXTRA_EOL
    $root,                           # ROOT
    $root,                           # CURRENT
    0,                               # LEVEL
    [],                              # TREE
  ], $class;

  $self->push($param{string}) if defined $param{string};

  $self
}


sub max_buffer_size {
  defined $_[0]->[BUF_MAX] ?
    $_[0]->[BUF_MAX]
    : ($_[0]->[BUF_MAX] = 0)
}

sub set_max_buffer_size {
  $_[0]->[BUF_MAX] = $_[1]
}


sub _maybe_extra_eol {
  $_[0]->[MAYBE_EXTRA_EOL]
}

sub _maybe_extra_eol_off {
  $_[0]->[MAYBE_EXTRA_EOL] = 0
}

sub _maybe_extra_eol_on {
  $_[0]->[MAYBE_EXTRA_EOL] = 1
}


sub _parse_current_buffer {
  my ($self) = @_;
  my $line = $self->[BUF];

  # skip blank/comments-only;
  unless ( Text::ZPL::_decode_prepare_line($line) ) {
    $self->[BUF] = '';
    return
  }

  Text::ZPL::_decode_handle_level(
    0, 
    $line, 
    $self->[ROOT],
    $self->[CURRENT],
    $self->[LEVEL],
    $self->[TREE],
  );
  
  if ( (my $sep_pos = index($line, '=')) > 0 ) {
    my ($k, $v) = Text::ZPL::_decode_parse_kv(
      0, $line, $self->[LEVEL], $sep_pos
    );
    Text::ZPL::_decode_add_kv(
      0, $self->[CURRENT], $k, $v
    );

    $self->[BUF] = '';
    return
  }

  my $re = $Text::ZPL::ValidName;
  if (my ($subsect) = $line =~ /^(?:\s+)?($re)(?:\s+?#.*)?$/) {
    Text::ZPL::_decode_add_subsection(
      0, $self->[CURRENT], $subsect, $self->[TREE]
    );

    $self->[BUF] = '';
    return
  }

  confess "Parse failed in ZPL stream; bad input '$line'"
}


sub get { shift->[ROOT] }

sub get_buffer { shift->[BUF] }


sub push {
  my $self = shift;
  # Accept strings, lists of strings, individual chrs:
  my @chrs = split '', join '', @_;

  my $handled = 0;

  CHAR: for my $chr (@chrs) {
    if ($chr eq "\015") {
      # got \r, maybe an unneeded \n coming up, _maybe_extra_eol_on
      $self->_maybe_extra_eol_on;
      $self->_parse_current_buffer;
      ++$handled;
      next CHAR
    }
    if ($chr eq "\012") {
      if ($self->_maybe_extra_eol) {
        $self->_maybe_extra_eol_off;
      } else {
        $self->_parse_current_buffer;
        ++$handled;
      }
      next CHAR
    }

    $self->_maybe_extra_eol_off if $self->_maybe_extra_eol;

    croak "Exceeded maximum buffer size for ZPL stream"
      if  $self->max_buffer_size
      and length($self->[BUF]) >= $self->max_buffer_size;

    $self->[BUF] .= $chr
  }

  $handled
}


1;
