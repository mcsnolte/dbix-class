use strict;
use warnings;
use Test::More;

use lib qw(t/lib);
use DBICTest;

use lib 't/bugs/load-order/lib';

use A::Schema::Result::Test_Computer;
use A::Schema::Result::Computer;
use A::Schema::Result::Test;

ok 1;
done_testing;
