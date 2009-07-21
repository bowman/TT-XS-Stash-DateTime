#!/usr/bin/perl

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'TT-XS-Stash-DateTime',
    'DIR'          => ['xs'],
    'VERSION'      => 1,
    'PMLIBDIRS'    => ['lib'], 
    'test'         => {
        'TESTS'    => join(' ', map { glob } qw( t/*.t )),
    },
);
