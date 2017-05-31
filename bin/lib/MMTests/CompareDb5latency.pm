# CompareDbt5latency.pm
package MMTests::CompareDbt5latency;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbt5latency",
		_DataType    => MMTests::Extract::DATA_TIME_SECONDS,
		_CompareOps  => [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
		_Variable    => 1,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
