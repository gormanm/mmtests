# CompareSembenchcommon.pm
package MMTests::CompareSembenchcommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSembenchcommon",
		_DataType    => MMTests::Compare::DATA_THROUGHPUT,
		_FieldLength => 12,
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
