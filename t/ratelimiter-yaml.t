#!perl -w
use strict;

use YAML qw(LoadFile);

use Data::Dumper;
warn Dumper LoadFile 't/ratelimits.yml';