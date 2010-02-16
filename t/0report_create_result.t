#!/usr/local/bin/perl

# program to run/test maint_ip_world_db

use strict;
use warnings;
use Test::More tests => 2;
use Module::Build;

my $result = Module::Build->current->config_data('result');
ok ($result, "able to access result of maint_ip_world_db");

ok ($result =~ /^Wrote database| is up-to-date/, "maint_ip_world_db: $result") 
or BAIL_OUT("\nWithout a database there can be no testing!\n");

# if there's no error. we still print the result line from maint_ip_world_db
diag ("maint_ip_world_db: $result");
