package Text::ZPL;

use Carp;
use strictures 1;

use Scalar::Util 'blessed', 'reftype';

use Path::Tiny;

sub decode_zpl {

}

sub _parse_zpl_block {
  my ($lines, $ref) = @_;
  $ref ||= +{};
  # FIXME
}

sub encode_zpl {
  my ($class, $obj) = @_;
  unless (ref $obj eq 'HASH') {
    if ($obj->can('TO_ZPL')) {
      $obj = $obj->TO_ZPL
    } else {
      confess "Expected a HASH but got $obj"
    }
  }

  _encode($obj)
}

sub _encode {
  my ($ref, $indent) = @_;
  $indent = 0 unless $indent;

  my $str = '';
  
  # FIXME name validation
  NODE: for my $key (keys %$ref) {
    $str .= ' ' x $indent;
    my $val = $ref->{$key};

    if (ref $val eq 'ARRAY') {
      for my $item (@$val) {
        $str .= ref $item ? 
          _encode($item, $indent + 4) : "$key = $val\n";
      }
      next NODE
    }

    if (ref $val eq 'HASH') {
      $str .= "$key\n";
      $str .= _encode($val, $indent + 4);
      next NODE
    }

    if (blessed $val && $val->can('TO_ZPL')) {
      my $realobj = $val->TO_ZPL;
      $str .= _encode($realobj, $indent + 4);
      next NODE
    }

    if (ref $val) {
      confess "Do not know how to handle object '$val'"
    }

    $str .= "$key = $val\n"
  } # NODE

  $str
}


sub from_file {
  my ($class, $path) = @_;
  confess "Expected a file path" unless defined $path;
  $path = path($path) unless blessed $path and $path->isa('Path::Tiny');
  confess "No such file ($path)" unless $path->exists;
  $class->decode_zpl( $path->slurp_utf8 )
}

sub to_file {
  my ($class, $path, $data) = @_;
  confess "Expected a file path" unless defined $path;
  $path = path($path) unless blessed $path and $path->isa('Path::Tiny');
  $path->spew_utf8( $class->encode_zpl($data) )
}


1;

# vim: ts=2 sw=2 et sts=2 ft=perl
