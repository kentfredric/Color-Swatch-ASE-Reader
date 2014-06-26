use strict;
use warnings;

use Test::More;
use Test::Differences qw( eq_or_diff );

# ABSTRACT: Test reading a swatch

use Color::Swatch::ASE::Reader;
use Path::Tiny qw(path);

my $out = Color::Swatch::ASE::Reader->read_file( path('./corpus/Spring_Blush.ase') );

eq_or_diff $out,
  {
  'blocks' => [
    {
      'group' => 13,
      'label' => 'Spring Blush',
      'type'  => 'group_start'
    },
    {
      'color_type' => 2,
      'group'      => 1,
      'model'      => 'RGB ',
      'type'       => 'color',
      'values'     => [ '0.364705890417099', '0.447058826684952', '0.647058844566345' ]
    },
    {
      'color_type' => 2,
      'group'      => 1,
      'model'      => 'RGB ',
      'type'       => 'color',
      'values'     => [ '0.733333349227905', '0.776470601558685', '0.313725501298904' ]
    },
    {
      'color_type' => 2,
      'group'      => 1,
      'model'      => 'RGB ',
      'type'       => 'color',
      'values'     => [ '0.839215695858002', '0.807843148708344', '0.564705908298492' ]
    },
    {
      'color_type' => 2,
      'group'      => 1,
      'model'      => 'RGB ',
      'type'       => 'color',
      'values'     => [ '0.345098048448563', '0.329411774873734', '0.23137255012989' ]
    },
    {
      'color_type' => 2,
      'group'      => 1,
      'model'      => 'RGB ',
      'type'       => 'color',
      'values'     => [ '0.749019622802734', '0.682352960109711', '0.580392181873322' ]
    },
    {
      'type' => 'group_end'
    }
  ],
  'signature' => 'ASEF',
  'version'   => [ 1, 0 ],
  },
  'ASE File decodes correctly';

done_testing;

