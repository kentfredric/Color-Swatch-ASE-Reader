use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Color::Swatch::ASE::Reader;

our $VERSION = '0.001000';

# ABSTRACT: Low-Level ASE (Adobe Swatch Exchange) File decoder

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Encode qw( decode );

sub read_file {
  my ( $class, $file ) = @_;
  require Path::Tiny;
  return $class->read_string( Path::Tiny::path($file)->slurp_raw );
}

sub read_filehandle {
  my ( $class, $filehandle ) = @_;
  return $class->read_string( scalar <$filehandle> );
}

sub read_string {
  my ( $class, $string ) = @_;
  my $clone = "$string";

  my $signature = $class->_read_signature( \$clone );
  my $version   = $class->_read_version( \$clone );
  my $numblocks = $class->_read_numblocks( \$clone );

  my @blocks;
  my $state = {};

  for my $id ( 1 .. $numblocks ) {
    push @blocks, $class->_read_block( \$clone, $id, $state );
  }

  if ( length $clone ) {
    warn( ( length $clone ) . " bytes of unhandled data" );
  }

  return {
    signature => $signature,
    version   => $version,
    blocks    => \@blocks
  };

}

sub _read_bytes {
  my ( $class, $string, $num, $decode ) = @_;
  return if ( length ${$string} ) < $num;
  my $chars = substr ${$string}, 0, $num, '';
  if ( 0 and $ENV{TRACE_ASE} ) {
    my $context = [ caller(1) ]->[3];
    my @chars = split //, $chars;
    print $context . " ";
    for my $char (@chars) {
      printf "%02x ", ord($char);
    }
    print "\n";
  }
  return unpack $decode, $chars if $decode;
  return $chars;
}

sub _read_signature {
  my ( $class, $string ) = @_;
  my $signature = $class->_read_bytes( $string, 4 );
  die "No ASEF signature " if not defined $signature or q[ASEF] ne $signature;
  return $signature;
}

sub _read_version {
  my ( $class, $string ) = @_;
  my (@version) = $class->_read_bytes( $string, 4, q[nn] );
  die "No VERSION header" if @version != 2;
  return \@version;
}

sub _read_numblocks {
  my ( $class, $string ) = @_;
  my $blocks = $class->_read_bytes( $string, 4, q[N] );
  die "No NUM BLOCKS header" if not defined $blocks;
  return $blocks;
}

sub _read_block_group {
  my ( $class, $string ) = @_;
  return $class->_read_bytes( $string, 2, q[n] );
}

sub _read_group_end {
  my ( $class, $id, $group, $label, $block_body, $state ) = @_;
  return {
    type => 'group_end',
    ( $group ? ( group => $group ) : () ),
    ( $label ? ( label => $label ) : () ),
  };
}

sub _read_group_start {
  my ( $class, $id, $group, $label, $block_body, $state ) = @_;
  return {
    type => 'group_start',
    ( $group ? ( group => $group ) : () ),
    ( $label ? ( label => $label ) : () ),
  };
}

sub _read_rgb {
  my ( $class, $block_body ) = @_;
  return $class->_read_bytes( $block_body, 12, 'f>f>f>' );
}

sub _read_color {
  my ( $class, $id, $group, $label, $block_body, $state ) = @_;
  my $model = $class->_read_bytes( $block_body, 4 );
  my @values;

  if ( not defined $model ) {
    die "No COLOR MODEL for block $id";
  }
  if ( q[RGB ] eq $model ) {
    @values = $class->_read_rgb($block_body);
  }
  elsif ( q[LAB ] eq $model ) {
    @values = $class->_read_lab($block_body);
  }
  elsif ( q[CMYK] eq $model ) {
    @values = $class->_read_cmyk($block_body);
  }
  elsif ( q[Gray] eq $model ) {
    @values = $class->_read_gray($block_body);
  }
  else {
    die "Unsupported model $model";
  }
  my $type = $class->_read_bytes( $block_body, 2, q[n] );
  return {
    type => 'color',
    ( $group ? ( group => $group ) : () ),
    ( $label ? ( label => $label ) : () ),
    ( $model ? ( model => $model ) : () ),
    values     => \@values,
    color_type => $type,
  };

}

sub _read_block_label {
  my ( $class, $string ) = @_;
  my ( $label, $rest )   = ( ${$string} =~ /\A(.*?)\x{00}\x{00}(.*\z)/msx );
  if ( defined $rest ) {
    ${$string} = "$rest";
  }
  else {
    ${$string} = "";
  }
  return decode( 'UTF-16BE', $label, Encode::FB_CROAK );
}

sub _read_block_type {
  my ( $class, $string, $id ) = @_;
  my $type = $class->_read_bytes( $string, 2 );
  die "No BLOCK TYPE for block $id" if not defined $type;
  return $type;
}

sub _read_block_length {
  my ( $class, $string, $id ) = @_;
  my $length = $class->_read_bytes( $string, 4, q[N] );
  die "No BLOCK LENGTH for block $id" if not defined $length;
  if ( ( length ${$string} ) < $length ) {
    warn "Possibly corrupt file, EOF before length $length in block $id";
  }
  return $length;
}

sub _read_block {
  my ( $class, $string, $id, $state ) = @_;
  my $type   = $class->_read_block_type($string);
  my $length = $class->_read_block_length($string);
  my $block_body;
  my $group;
  my $label;
  if ( $length > 0 ) {
    $block_body = $class->_read_bytes( $string, $length );
    $group      = $class->_read_block_group( \$block_body );
    $label      = $class->_read_block_label( \$block_body );
  }

  if ( "\x{c0}\x{02}" eq $type ) {
    return $class->_read_group_end( $id, $group, $label, \$block_body, $state );
  }
  if ( "\x{c0}\x{01}" eq $type ) {
    return $class->_read_group_start( $id, $group, $label, \$block_body, $state );
  }
  if ( "\x{00}\x{01}" eq $type ) {
    return $class->_read_color( $id, $group, $label, \$block_body, $state );
  }
  die "Unknown type $type";

}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Color::Swatch::ASE::Reader - Low-Level ASE (Adobe Swatch Exchange) File decoder

=head1 VERSION

version 0.001000

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
