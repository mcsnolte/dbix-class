use strict;
use warnings;
use Test::More;

use lib qw(t/lib);
use DBICTest;

use lib 't/bugs/load-order/lib';

use A::Schema::Result::Computer;
use A::Schema::Result::Test;
use A::Schema::Result::Test_Computer;

ok 1;
done_testing;
