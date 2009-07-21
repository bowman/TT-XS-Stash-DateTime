#============================================================= -*-perl-*-
#
# t/stash-xs.t
#
# Script testing the stripped down Template::Stash::XS to explore the
# DateTime bug.
#
# Written by Andy Wardley <abw@wardley.org>
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../blib/lib ../blib/arch ./blib/lib ./blib/arch );
use DateTime;
use Template::Stash::XS;
use Test::More tests => 3;

my $stash = Template::Stash::XS->new({
    date_time     => DateTime->now,
    date_time_sub => sub { DateTime->now },
});

print "The year is ", $stash->get('date_time')->year, "\n";

