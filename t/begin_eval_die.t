#============================================================= -*-perl-*-
#
# t/begin_eval_die.t
#
# Script testing the stripped down Template::Stash::XS to explore the
# but formerly known as DateTime...
# https://rt.cpan.org/Public/Bug/Display.html?id=47929
#
# Written by Andy Wardley <abw@wardley.org>
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../blib/lib ../blib/arch ./blib/lib ./blib/arch );
use Template::Stash::XS;
use Test::More tests => 1;

my $vars = {
    eval_fail     => sub {
        eval "BEGIN { die 'compile time die' }";
        return "eval failed";
    },
};
my $stash  = Template::Stash::XS->new($vars);
my $result = $stash->get('eval_fail');
is( $result, 'eval failed', "eval failed as expected" );

