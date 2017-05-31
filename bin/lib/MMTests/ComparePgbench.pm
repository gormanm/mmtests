# ComparePgbench.pm
package MMTests::ComparePgbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePgbench",
		_DataType    => MMTests::Extract::DATA_TRANS_PER_SECOND,
		_CompareOps  => [ "pndiff", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff" ],
		_Variable    => 1,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
