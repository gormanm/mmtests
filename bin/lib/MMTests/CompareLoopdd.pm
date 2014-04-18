# CompareLoopdd.pm
package MMTests::CompareLoopdd;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareLoopdd",
		_DataType    => MMTests::Compare::DATA_OPSSEC,
		_Precision   => 4,
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractComparison() {
	my ($self, $subHeading, $showCompare) = @_;

	$self->{_CompareOp} = "pndiff";
	if ($subHeading eq /time/ ) {
		$self->{_CompareOp} = "pdiff";
	}

	$self->SUPER::extractComparison($subHeading, $showCompare);
}

1;
