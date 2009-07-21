#============================================================= -*-perl-*-
#
# t/datetime.t
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
use Test::More tests => 2;
use Template;

my $year = DateTime->now->year;
my $vars = {
    date_time     => DateTime->now,
    date_time_sub => sub { 
        warn "# Creating DateTime object\n";
        my $dt = DateTime->now( time_zone => 'local' );
        warn "# Created DateTime object, returning\n";
        return $dt;
    },
};
my $stash = Template::Stash::XS->new($vars);

my $result = $stash->get('date_time')->year;
is( $result, $year, "The year is $result (DateTime object)" );

$result = $stash->get('date_time_sub')->year;
is( $result, $year, "The year is $result (subroutine returning DateTime object)" );

