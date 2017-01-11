# CompareSimooprates.pm
package MMTests::CompareSimooprates;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSimooprates",
		_DataType    => MMTests::Extract::DATA_OPS_PER_SECOND,
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
