# CompareSysbench.pm
package MMTests::CompareSysbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSysbench",
		_DataType    => MMTests::Extract::DATA_TRANS_PER_SECOND,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pdiff", "pdiff", "pdiff", "pndiff", "pdiff", "pdiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
