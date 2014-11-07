# CompareParallelioio.pm
package MMTests::CompareParallelioio;
use VMR::Stat;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareParallelioio",
		_DataType    => MMTests::Compare::DATA_TIME_SECONDS,
		_FieldLength => 18,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
