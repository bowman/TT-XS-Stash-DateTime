use lib qw( ../lib ./lib );
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'     => 'Template::Stash::XS',
    'C'        => [ qw( Stash.c ) ],
    'XS'       => { 'Stash.xs' => 'Stash.c' },
    'OBJECT'   => 'Stash.o',
    'VERSION'  => 1,
    'NORECURS' => 1,
);

