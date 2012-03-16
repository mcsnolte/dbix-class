use strict;
use warnings;

use lib qw(t/lib);
use Test::More;
use Test::Exception;
use DBICTest;

my $schema = DBICTest->init_schema();
my $rs = $schema->resultset('CD');
my $row = $rs->new_result({});

dies_ok { $row->has_relationship_loaded() }
  'has_relationship_loaded needs a relationship name';

ok !$row->has_relationship_loaded($_), "vanilla row has no loaded relationship '$_'"
  for $row->result_source->relationships;

# Prefetch of single belongs_to relationship
{
  my $prefetched_rs = $rs->search_rs(undef, { prefetch => 'artist' });
  my $cd = $prefetched_rs->find(1);
  ok $cd->has_relationship_loaded('artist'), 'belongs_to relationship with related row detected by has_relationship_loaded';
}

# Prefetch of single might_have relationship
{
  my $prefetched_rs = $rs->search_rs(undef, { prefetch => 'liner_notes' });
  my $cd_without_liner_notes = $prefetched_rs->find(1);
  ok $cd_without_liner_notes->has_relationship_loaded('liner_notes'), 'might_have relationship without related row detected by has_relationship_loaded';
  my $cd_with_liner_notes = $prefetched_rs->find(2);
  ok $cd_with_liner_notes->has_relationship_loaded('liner_notes'), 'might_have relationship with related row detected by has_relationship_loaded';
}

# Prefetch of single has_many relationship
{
  my $prefetched_rs = $rs->search_rs(undef, { prefetch => 'tracks' });
  my $cd_without_tracks = $prefetched_rs->create({
    artist => 1,
    title  => 'Empty CD',
    year   => 2012,
  });
  ok $cd_without_tracks->has_relationship_loaded('tracks'), 'has_many relationship without related row detected by has_relationship_loaded';
  my $cd_with_tracks = $prefetched_rs->find(2);
  ok $cd_with_tracks->has_relationship_loaded('tracks'), 'has_many relationship with related row detected by has_relationship_loaded';
}

# Prefetch of multiple relationships
{
  my $prefetched = $rs->search_rs(undef, { prefetch => ['artist', 'tracks'] })->first;
  ok $prefetched->has_relationship_loaded('artist'), 'first prefetch detected by has_relationship_loaded';
  ok $prefetched->has_relationship_loaded('tracks'), 'second prefetch detected by has_relationship_loaded';
}

# Prefetch of nested relationships
{
  my $prefetched = $schema->resultset('Artist')->search_rs(undef, { prefetch => {'cds' => 'tracks'} })->find(1);
  ok $prefetched->has_relationship_loaded('cds'), 'direct prefetch detected by has_relationship_loaded';
  ok $prefetched->cds->first->has_relationship_loaded('tracks'), 'nested prefetch detected by has_relationship_loaded';
}

done_testing;