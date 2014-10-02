package Text::ZPL;

use Carp;
use strictures 1;

use Scalar::Util 'blessed', 'reftype';

use Path::Tiny;


use parent 'Exporter::Tiny';
our @EXPORT = our @EXPORT_OK = qw/
  encode_zpl
  decode_zpl
/;

our $ValidName = qr/^[A-Za-z0-9\$\-_\@.&+\/]+$/;


sub decode_zpl {
  my ($str) = @_;

  my @lines = [ split /(?:\r?\n)|\r/, $str ];

  my $root = +{};
  my $ref = $root;
  LINE: while (@lines) {
    my $line = shift @lines;
  } # LINE

  $root
}

sub encode_zpl {
  my ($obj) = @_;
  $obj = $obj->TO_ZPL if blessed $obj and $obj->can('TO_ZPL');
  confess "Expected a HASH but got $obj" unless ref $obj eq 'HASH';
  _encode($obj)
}

sub _encode {
  my ($ref, $indent) = @_;
  $indent = 0 unless $indent;

  my $str = '';
  
  NODE: for my $key (keys %$ref) {
    confess "$key is not a valid ZPL property name"
      unless $key =~ $ValidName;

    $str .= ' ' x $indent;
    my $val = $ref->{$key};

    if (ref $val eq 'ARRAY') {
      for my $item (@$val) {
        $str .= ref $item ? 
          _encode(+{ $key => $item }, $indent + 4) : "$key = $item\n";
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



1;

# vim: ts=2 sw=2 et sts=2 ft=perl
