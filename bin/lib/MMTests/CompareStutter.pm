# CompareStutter.pm
package MMTests::CompareStutter;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareStutter",
		_DataType    => MMTests::Compare::DATA_WALLTIME,
		_CompareOp   => "pndiff",
		_Precision   => 4,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
