use strict;
use warnings;

use Test::More;

use lib qw(t/lib);

use DBICTest;

plan tests => 5;

my $schema = DBICTest->init_schema();

my $cds = $schema->resultset("CD")->search({ cdid => 1 }, { join => { cd_to_producer => 'producer' } });
cmp_ok($cds->count, '>', 1, "extra joins explode entity count");

is (
  $cds->search({}, { prefetch => 'cd_to_producer' })->count,
  1,
  "Count correct with extra joins collapsed by prefetch"
);

is (
  $cds->search({}, { distinct => 1 })->count,
  1,
  "Count correct with requested distinct collapse of main table"
);

my $artist=$schema->resultset('Artist')->create({name => 'xxx'});
is($artist->related_resultset('cds')->count(), 0,
   "No CDs found for a shiny new artist");
my $artist_rs = $schema->resultset('Artist')->search({artistid => $artist->id});
is($artist_rs->related_resultset('cds')->count(), 0,
   "No CDs found for a shiny new artist using a resultset search");

