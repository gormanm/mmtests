# CompareParallelioswap.pm
package MMTests::CompareParallelioswap;
use VMR::Stat;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareParallelioswap",
		_DataType    => MMTests::Extract::DATA_ACTIONS,
		_FieldLength => 18,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
