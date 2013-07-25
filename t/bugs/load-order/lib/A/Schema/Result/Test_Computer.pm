package A::Schema::Result::Test_Computer;

use base 'DBIx::Class::Core';

__PACKAGE__->table('Test_Computer');
__PACKAGE__->add_columns(qw( test_id ));
__PACKAGE__->_add_join_column({ class => 'A::Schema::Result::Computer', method => 'computer' });
__PACKAGE__->set_primary_key('test_id', 'computer_id');
__PACKAGE__->belongs_to(test => 'A::Schema::Result::Test', 'test_id');
__PACKAGE__->belongs_to(computer => 'A::Schema::Result::Computer', 'computer_id');

sub _add_join_column {
   my ($self, $params) = @_;

   my $class = $params->{class};
   my $method = $params->{method};

   $self->ensure_class_loaded($class);

   my @class_columns = $class->primary_columns;

   if (@class_columns = 1) {
      $self->add_columns( "${method}_id" );
   } else {
      my $i = 0;
      for (@class_columns) {
         $i++;
         $self->add_columns( "${method}_${i}_id" );
      }
   }
}

1;
