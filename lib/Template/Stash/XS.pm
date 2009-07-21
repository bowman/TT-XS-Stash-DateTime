#============================================================= -*-Perl-*-
# 
# Template::Stash::XS
# 
# DESCRIPTION
#   Perl bootstrap for XS module. Inherits methods from 
#   Template::Stash when not implemented in the XS module.
#
#========================================================================

package Template::Stash::XS;

use strict;
use warnings;
use Template::Stash;

our $AUTOLOAD;

BEGIN {
    require DynaLoader;
    @Template::Stash::XS::ISA = qw( DynaLoader Template::Stash );

    eval {
        bootstrap Template::Stash::XS 1;
    };
    if ($@) {
        die "Couldn't load Template::Stash::XS:\n  $@\n";
    }
}

sub DESTROY {
    # no op
    1;
}


# catch missing method calls here so perl doesn't barf 
# trying to load *.al files 

sub AUTOLOAD {
    my ($self, @args) = @_;
    my @c             = caller(0);
    my $auto	    = $AUTOLOAD;

    $auto =~ s/.*:://;
    $self =~ s/=.*//;

    die "Can't locate object method \"$auto\"" .
        " via package \"$self\" at $c[1] line $c[2]\n";
}

1;

