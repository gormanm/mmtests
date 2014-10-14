# CompareDbench4latency.pM
package MMTests::CompareDbench4latency;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbench4latency",
		_DataType    => MMTests::Extract::DATA_TIME_MSECONDS,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
