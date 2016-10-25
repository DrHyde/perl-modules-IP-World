#!/usr/local/bin/perl

# program to test IP::World

use strict;
use warnings;
use Test::More;
END { done_testing }
use t::lib::tests;

use IP::World;

my $ipw = IP::World->new(0);

tests($ipw);
