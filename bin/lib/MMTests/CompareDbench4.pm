# CompareDbench4.pm
package MMTests::CompareDbench4;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbench4",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pdiff", "pdiff", "pdiff", "pndiff", "pdiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractComparison() {
	my ($self, $subHeading, $showCompare) = @_;

	if ($subHeading eq "Latency" ) {
		$self->{_CompareOps} = [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
	}

	$self->SUPER::extractComparison($subHeading, $showCompare);
}

1;
