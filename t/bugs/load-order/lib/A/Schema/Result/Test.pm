package A::Schema::Result::Test;

use base 'DBIx::Class::Core';

__PACKAGE__->table('Tests');

__PACKAGE__->add_columns('id');

__PACKAGE__->set_primary_key('id');

1;
