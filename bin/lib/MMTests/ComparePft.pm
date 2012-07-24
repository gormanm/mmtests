# ComparePft.pm
package MMTests::ComparePft;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

use constant DATA_PFT           => 200;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePft",
		_DataType    => DATA_PFT,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pndiff", "pndiff", "pndiff", "pdiff", "pdiff" ],
		_Precision   => 4,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
