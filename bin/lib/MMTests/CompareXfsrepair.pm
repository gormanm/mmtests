# CompareXfsrepair.pm
package MMTests::CompareXfsrepair;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareXfsrepair",
		_DataType    => MMTests::Compare::DATA_WALLTIME,
		_CompareOps  => [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
