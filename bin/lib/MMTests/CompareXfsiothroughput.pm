# CompareXfsiothroughput.pm
package MMTests::CompareXfsiothroughput;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareXfsiothroughput",
		_DataType    => MMTests::Compare::DATA_MBYTES_PER_SECOND,
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
