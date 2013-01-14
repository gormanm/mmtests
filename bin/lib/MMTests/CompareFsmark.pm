# CompareFsmark.pm
package MMTests::CompareFsmark;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFsmark",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pdiff", "pdiff", "pdiff", "pndiff", "pdiff" ],
		_CompareLength => 6,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}


sub extractComparison() {
	my ($self, $subHeading, $showCompare) = @_;

	if ($subHeading eq "Overhead" ) {
		$self->{_CompareOps} = [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
	}

	$self->SUPER::extractComparison($self, $subHeading, $showCompare);
}

1;
