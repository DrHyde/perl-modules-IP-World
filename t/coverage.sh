#!/bin/sh
cover -delete
HARNESS_PERL_SWITCHES=-MDevel::Cover ./Build test
cover
