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
use Test::More tests => 4;
use Template;

my $year = DateTime->now->year;
my $vars = {
    date_time     => DateTime->now,
    date_time_sub => sub { 
        print STDERR "Creating DateTime object\n";
        my $dt = DateTime->now;
        print STDERR "Created DateTime object, returning\n";
        return $dt;
    },
};
my $stash = Template::Stash::XS->new($vars);

my $result = $stash->get('date_time')->year;
is( $result, $year, "The year is $result (DateTime object)" );

$result = $stash->get('date_time_sub')->year;
is( $result, $year, "The year is $result (subroutine returning DateTime object)" );

my $tt = Template->new(
    BLOCKS => {
        dt  => "ok 3 - The date is [% date_time %]\n",
        dts => "ok 4 - The date is [% date_time_sub %]\n",
    }
);

# NOTE: this bypasses Test::More so expect "4 tests planned but ran 2"
$tt->process( dt => $vars );
$tt->process( dts => $vars );
