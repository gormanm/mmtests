# ComparePgbench.pm
package MMTests::ComparePgbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePgbench",
		_DataType    => MMTests::Compare::DATA_THROUGHPUT,
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractComparison() {
	my ($self, $subHeading, $showCompare) = @_;

	if ($subHeading eq "LoadTime") {
		$self->{_CompareOps} = [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
	} elsif ($subHeading eq "TransTime") {
		$self->{_CompareOps} = [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ];
	} else {
		$self->{_CompareOps} = [ "none", "pdiff", "pdiff", "pndiff", "pdiff", "pdiff", "pdiff" ];
	}

	return $self->SUPER::extractComparison($subHeading, $showCompare);
}

1;
