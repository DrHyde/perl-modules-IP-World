#!/usr/local/bin/perl

# program to run/test maint_ip_world_db

use strict;
use warnings;
use Test::More tests => 4;
#use Test::Script            rejected for too many dependencies
use Module::Build;

my $build = Module::Build->current();
my $tail = $build->is_unixish() ? ' 2>&1' : '';

# maint_ip_world_db was already run as part of the build step
# we will test its results last

# check syntax of the dump program
#script_compiles ('script/ip_world_dump', "ip_world_dump syntax OK");
my $result = `$^X -c script/ip_world_dump$tail`;
chomp $result;
ok (!($?>>8), $result);

# check syntax of the benchmark program
#script_compiles ('script/ip_cc_benchmark', "ip_cc_benchmark syntax OK");
$result = `$^X -c script/ip_cc_benchmark$tail`;
chomp $result;
ok (!($?>>8), $result);

$result = $build->config_data('result');
chomp $result;
ok ($result, "able to access result of maint_ip_world_db");

# print the result from maint_ip_world_db
diag ("maint_ip_world_db: $result");

my $ok = $result =~ /Wrote IP::World database| is up-to-date/;
ok ($ok, "maint_ip_world_db executed ".($ok ? "" : "un")."successfully")

# don't let other tests go on without a DB 
or BAIL_OUT("\nWithout a database there can be no testing!\n");
