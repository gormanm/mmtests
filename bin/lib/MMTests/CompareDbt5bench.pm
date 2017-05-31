# CompareDbt5bench.pm
package MMTests::CompareDbt5bench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbt5bench",
		_DataType    => MMTests::Extract::DATA_TIME_MSECOND,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
