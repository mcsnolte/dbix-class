package A::Schema::Result::Computer;

use base 'DBIx::Class::Core';

__PACKAGE__->table('Computers');

__PACKAGE__->add_columns('id');

__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(computer_test_links => 'A::Schema::Result::Test_Computer', 'computer_id');

1;
