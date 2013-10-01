# CompareTimeexit.pm
package MMTests::CompareKu_latency;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareKu_latency",
		_DataType    => MMTests::Extract::DATA_WALLTIME_VARIABLE,
		_FieldLength => 12,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
