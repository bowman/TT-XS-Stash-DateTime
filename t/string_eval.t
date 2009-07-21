#============================================================= -*-perl-*-
#
# t/string_eval.t
#
# Script testing the stripped down Template::Stash::XS to explore the
# DateTime bug... which now appears to be unrelated to DateTime, but
# due to an eval string.
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
        warn "# About to use NonExistantClass\n";
        eval "use Nonexistent::Class";
        if ($@) {
            warn "# Caught expected failure to use Nonexistent::Class";
        }
        return "eval failed";
    },
};
my $stash  = Template::Stash::XS->new($vars);
my $result = $stash->get('eval_fail');
is( $result, 'eval failed', "eval failed as expected" );

