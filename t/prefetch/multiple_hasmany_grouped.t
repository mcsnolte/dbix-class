use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Exception;
use lib qw(t/lib);
use DBICTest;

my $schema = DBICTest->init_schema();

my $mo_rs = $schema->resultset('Artist')->search(
	{ 'me.artistid' => 4 },
	{
		prefetch => { cds => { tracks => { lyrics => 'lyric_versions' } } },

		rows => 2,    # Added

		order_by => 'lyrics.track_id',    # fail

		#order_by => [qw/tracks.position lyrics.track_id/], # works
		#order_by => [qw/cds.year lyrics.track_id/],        # also works

		result_class => 'DBIx::Class::ResultClass::HashRefInflator',
	}
);

$schema->resultset('Artist')->create(
	{
		name => 'mo',
		rank => '1337',
		cds  => [
			{
				title  => 'Song of a Foo',
				year   => '1999',
				tracks => [
					{
						title  => 'Foo Me Baby One More Time',
						lyrics => { lyric_versions => [ { text => 'Foo', } ] }
					},
				]
			}
		]
	}
);

my $mo = $mo_rs->next;

is( @{ $mo->{cds} }, 1, 'one CD' );

cmp_deeply(
	$mo,
	{
		'artistid' => 4,
		'cds'      => [
			{
				'artist'       => 4,
				'cdid'         => 6,
				'genreid'      => undef,
				'single_track' => undef,
				'title'        => 'Song of a Foo',
				'tracks'       => [
					{
						'cd'              => 6,
						'last_updated_at' => undef,
						'last_updated_on' => undef,
						'lyrics'          => {
							'lyric_id'       => 1,
							'lyric_versions' => [
								{
									'id'       => 1,
									'lyric_id' => 1,
									'text'     => 'Foo'
								}
							],
							'track_id' => 19
						},
						'position' => 1,
						'title'    => 'Foo Me Baby One More Time',
						'trackid'  => 19
					}
				],
				'year' => '1999'
			}
		],
		'charfield' => undef,
		'name'      => 'mo',
		'rank'      => 1337
	}
);

done_testing;
