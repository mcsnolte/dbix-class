use strict;
use warnings;  
no warnings 'uninitialized';

use Test::More;
use Test::Exception;
use lib qw(t/lib);
use DBICTest;

my ($dsn, $user, $pass) = @ENV{map { "DBICTEST_SYBASE_${_}" } qw/DSN USER PASS/};

my $TESTS = 29 + 2;

if (not ($dsn && $user)) {
  plan skip_all =>
    'Set $ENV{DBICTEST_SYBASE_DSN}, _USER and _PASS to run this test' .
    "\nWarning: This test drops and creates the tables " .
    "'artist' and 'bindtype_test'";
} else {
  plan tests => $TESTS*2;
}

my @storage_types = (
  'DBI::Sybase',
  'DBI::Sybase::NoBindVars',
);
my $schema;
my $storage_idx = -1;

for my $storage_type (@storage_types) {
  $storage_idx++;
# this is so we can set ->storage_type before connecting
  my $schema = DBICTest::Schema->clone;

  unless ($storage_type eq 'DBI::Sybase') { # autodetect
    $schema->storage_type("::$storage_type");
  }

  $schema->connection($dsn, $user, $pass, {
    AutoCommit => 1,
    on_connect_call => [
      [ blob_setup => log_on_update => 1 ], # this is a safer option
    ],
  });

  $schema->storage->ensure_connected;

  if ($storage_idx == 0 &&
      $schema->storage->isa('DBIx::Class::Storage::DBI::Sybase::NoBindVars')) {
# no placeholders in this version of Sybase or DBD::Sybase (or using FreeTDS)
      my $tb = Test::More->builder;
      $tb->skip('no placeholders') for 1..$TESTS;
      next;
  }

  isa_ok( $schema->storage, "DBIx::Class::Storage::$storage_type" );

  $schema->storage->_dbh->disconnect;
  lives_ok (sub { $schema->storage->dbh }, 'reconnect works');

  $schema->storage->dbh_do (sub {
      my ($storage, $dbh) = @_;
      eval { $dbh->do("DROP TABLE artist") };
      $dbh->do(<<'SQL');
CREATE TABLE artist (
   artistid INT IDENTITY PRIMARY KEY,
   name VARCHAR(100),
   rank INT DEFAULT 13 NOT NULL,
   charfield CHAR(10) NULL
)
SQL
  });

  my %seen_id;

# so we start unconnected
  $schema->storage->disconnect;

# inserts happen in a txn, so we test txn nesting
  $schema->txn_begin;

# test primary key handling
  my $new = $schema->resultset('Artist')->create({ name => 'foo' });
  ok($new->artistid > 0, "Auto-PK worked");

  $seen_id{$new->artistid}++;

  for (1..6) {
    $new = $schema->resultset('Artist')->create({ name => 'Artist ' . $_ });
    is ( $seen_id{$new->artistid}, undef, "id for Artist $_ is unique" );
    $seen_id{$new->artistid}++;
  }

  $schema->txn_commit;

# test simple count
  is ($schema->resultset('Artist')->count, 7, 'count(*) of whole table ok');

# test LIMIT support
  my $it = $schema->resultset('Artist')->search({
    artistid => { '>' => 0 }
  }, {
    rows => 3,
    order_by => 'artistid',
  });

  is( $it->count, 3, "LIMIT count ok" );

  is( $it->next->name, "foo", "iterator->next ok" );
  $it->next;
  is( $it->next->name, "Artist 2", "iterator->next ok" );
  is( $it->next, undef, "next past end of resultset ok" );

# now try with offset
  $it = $schema->resultset('Artist')->search({}, {
    rows => 3,
    offset => 3,
    order_by => 'artistid',
  });

  is( $it->count, 3, "LIMIT with offset count ok" );

  is( $it->next->name, "Artist 3", "iterator->next ok" );
  $it->next;
  is( $it->next->name, "Artist 5", "iterator->next ok" );
  is( $it->next, undef, "next past end of resultset ok" );

# now try a grouped count
  $schema->resultset('Artist')->create({ name => 'Artist 6' })
    for (1..6);

  $it = $schema->resultset('Artist')->search({}, {
    group_by => 'name'
  });

  is( $it->count, 7, 'COUNT of GROUP_BY ok' );

# mostly stolen from the blob stuff Nniuq wrote for t/73oracle.t
  SKIP: {
    skip 'TEXT/IMAGE support does not work with FreeTDS', 12
      if $schema->storage->_using_freetds;

    my $dbh = $schema->storage->dbh;
    {
      local $SIG{__WARN__} = sub {};
      eval { $dbh->do('DROP TABLE bindtype_test') };

      $dbh->do(qq[
        CREATE TABLE bindtype_test 
        (
          id    INT   IDENTITY PRIMARY KEY,
          bytea INT   NULL,
          blob  IMAGE NULL,
          clob  TEXT  NULL
        )
      ],{ RaiseError => 1, PrintError => 0 });
    }

    my %binstr = ( 'small' => join('', map { chr($_) } ( 1 .. 127 )) );
    $binstr{'large'} = $binstr{'small'} x 1024;

    my $maxloblen = length $binstr{'large'};
    note
      "Localizing LongReadLen to $maxloblen to avoid truncation of test data";
    local $dbh->{'LongReadLen'} = $maxloblen * 2;

    my $rs = $schema->resultset('BindType');
    my $last_id;

    foreach my $type (qw(blob clob)) {
      foreach my $size (qw(small large)) {
        no warnings 'uninitialized';

        my $created = eval { $rs->create( { $type => $binstr{$size} } ) };
        ok(!$@, "inserted $size $type without dying");
        diag $@ if $@;

        $last_id = $created->id if $created;

        my $got = eval {
          $rs->find($last_id)->$type
        };
        diag $@ if $@;
        ok($got eq $binstr{$size}, "verified inserted $size $type");
      }
    }

    # blob insert with explicit PK
    # also a good opportunity to test IDENTITY_INSERT
    {
      local $SIG{__WARN__} = sub {};
      eval { $dbh->do('DROP TABLE bindtype_test') };

      $dbh->do(qq[
        CREATE TABLE bindtype_test 
        (
          id    INT   IDENTITY PRIMARY KEY,
          bytea INT   NULL,
          blob  IMAGE NULL,
          clob  TEXT  NULL
        )
      ],{ RaiseError => 1, PrintError => 0 });
    }
    my $created = eval { $rs->create( { id => 1, blob => $binstr{large} } ) };
    ok(!$@, "inserted large blob without dying with manual PK");
    diag $@ if $@;

    my $got = eval {
      $rs->find(1)->blob
    };
    diag $@ if $@;
    ok($got eq $binstr{large}, "verified inserted large blob with manual PK");

    # try a blob update
    my $new_str = $binstr{large} . 'mtfnpy';
    eval { $rs->search({ id => 1 })->update({ blob => $new_str }) };
    ok !$@, 'updated blob successfully';
    diag $@ if $@;
    $got = eval {
      $rs->find(1)->blob
    };
    diag $@ if $@;
    ok($got eq $new_str, "verified updated blob");
  }
}

# clean up our mess
END {
  if (my $dbh = eval { $schema->storage->_dbh }) {
    $dbh->do('DROP TABLE artist');
    eval { $dbh->do('DROP TABLE bindtype_test')    };
  }
}
