# ComparePgbench.pm
package MMTests::ComparePgbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePgbench",
		_DataType    => MMTests::Compare::DATA_THROUGHPUT,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pdiff", "pdiff", "pdiff", "pndiff", "pdiff", "pdiff" ];
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
