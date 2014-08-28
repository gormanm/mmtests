# CompareSysbench.pm
package MMTests::CompareSysbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSysbench",
		_DataType    => MMTests::Compare::DATA_THROUGHPUT,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pdiff", "pdiff", "pdiff", "pndiff", "pdiff", "pdiff" ],
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
		$self->{_CompareOps} = [ "none", "pdiff", "pdiff", "pdiff", "pndiff", "pdiff", "pdiff" ];
	}

	return $self->SUPER::extractComparison($subHeading, $showCompare);
}

1;
