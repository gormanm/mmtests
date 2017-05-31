# CompareStockfish.pm
package MMTests::CompareStockfish;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareStockfish",
		_DataType    => MMTests::Extract::DATA_OPS_PER_SECOND,
		_FieldLength => 12,
	};
	bless $self, $class;
	return $self;
}

1;
