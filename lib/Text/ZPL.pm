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

# note: not anchored as-is:
our $ValidName = qr/[A-Za-z0-9\$\-_\@.&+\/]+/;


sub decode_zpl {
  my ($str) = @_;

  my @lines = split /(?:\r?\n)|\r/, $str;

  my $root = +{};
  my $ref  = $root;
  my @descended;

  my $level   = 0;
  my $lineno  = 0;

  LINE: for my $line (@lines) {
    ++$lineno;

    # Trim trailing WS:
    $line =~ s/\s+$//;

    # Skip blank after trim, comments-only
    next LINE if length($line) == 0 or $line =~ /^(?:\s+)?#/;

    my $cur_indent = __get_indent($lineno, $line);
    
    # Manage indentation-based hierarchy:
    if ($cur_indent > $level) {
      unless (defined $descended[ ($cur_indent / 4) - 1 ]) {
        confess "Invalid ZPL (line $lineno); no matching parent section",
          " [$line]"
      }
      $level = $cur_indent; 
    } elsif ($cur_indent < $level) {
      my $wanted_idx = ( ($level - $cur_indent) / 4 ) - 1 ;
      my $wanted_ref = $descended[$wanted_idx];
      unless (defined $wanted_ref) {
        confess
          "BUG; cannot find matching parent section"
          ." [idx = $wanted_idx] [indent = $cur_indent]"
      }
      $ref = $wanted_ref;
      my $startidx = $wanted_idx + 1;
      @descended = @descended[$startidx .. $#descended];
      $level = $cur_indent;
    }

    # KV pair:
    if ( (my $sep_pos = index($line, '=')) > 0 ) {
      my $key = substr $line, $level, ( $sep_pos - $level );
      $key =~ s/\s+$//;
      # FIXME verify key
      my $val = substr $line, $sep_pos + 1;
      $val =~ s/^\s+//;

      my $realval;
      my $vpos = 0;

      my $maybe_q = substr $val, 0, 1;
      undef $maybe_q unless $maybe_q eq q{'} or $maybe_q eq q{"};
      if (defined $maybe_q) {
        # Quoted
        if ((my $matching_q_pos = index $val, $maybe_q, 1) > 1) {
          # Consume up to matching quote
          $realval = substr $val, 1, ($matching_q_pos - 1), '';
          $val = '' if $val eq $maybe_q x 2;
        } else {
          # No matching quote
          my $maybe_trailing = index $val, ' ';
          $maybe_trailing = length $val unless $maybe_trailing > -1;
          $realval = substr $val, 0, $maybe_trailing, '';
        }
      } else {
        # Unquoted
        my $maybe_trailing = index $val, ' ';
        $maybe_trailing = length $val unless $maybe_trailing > -1;
        $realval = substr $val, 0, $maybe_trailing, '';
      }

      # Should've thrown away usable pieces:
      $val =~ s/(?:\s+)|(?:#.*)//;
      if (length $val) {
        confess "Invalid ZPL (line $lineno); garbage at end-of-line '$val'"
      }
      undef $val;

      if (exists $ref->{$key}) {
        if (ref $ref->{$key} eq 'HASH') {
          confess
            "Invalid ZPL (line $lineno); existing subsection with this  name"
        } elsif (ref $ref->{$key} eq 'ARRAY') {
          push @{ $ref->{$key} }, $realval
        } else {
          my $oldval = $ref->{$key};
          $ref->{$key} = [ $oldval, $realval ]
        }
      } else {
        $ref->{$key} = $realval
      }

      next LINE
    }

    # New subsection:
    if (my ($subsect) = $line =~ /^(?:\s+)?($ValidName)(?:#.+)?$/) {
      # FIXME confess if this matches an existing key
      my $new_ref = ($ref->{$subsect} = +{});
      unshift @descended, $ref;
      $ref = $new_ref;
      next LINE
    }

    confess "Invalid ZPL (line $lineno); unrecognized syntax: '$line'"

    # Check indent level
    #   if $new_indent doesn't match $level,
    #     if $new_indent less than $level:
    #       $wanted_idx = ( ( ($level - $new_indent) / 4 ) - 1 )
    #       $wanted_ref = $descended[ $wanted_idx ]
    #       adjust $level = $new_indent
    #       adjust @descended = @descended[ $wanted_idx .. $#descended ]
    #     if $new_indent greater than $level:
    #       $wanted_ref = $descended[ $new_indent ];
    #       adjust $level = $new_indent
    # If this looks like a subsection name,
    #   add 

  } # LINE

  # FIXME
  # track descendants in @descended
  #  if dropping indent, pop for every 4 spaces to get $current ref
  #  ::_get_indent sub to find out?
  #  

  $root
}

sub __get_indent {
  my ($lineno, $line) = @_;
  my $pos = 0;
  $pos++ while substr($line, $pos, 1) eq ' ';
  if ($pos % 4) {
    confess
      "Invalid ZPL (line $lineno); expected 4-space indent, indent is $pos"
  }
  $pos
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
      unless $key =~ qr/^$ValidName$/;

    $str .= ' ' x $indent;

    my $val = $ref->{$key};

    if (ref $val eq 'ARRAY') {
      for my $item (@$val) {
        $str .= ref $item ? 
            _encode(+{ $key => $item }, $indent + 4) 
          : "$key = $item\n";
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
