# CompareIozone.pm
package MMTests::CompareIozone;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareIozone",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_FieldLength => 12,
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractComparison() {
	my ($self, $subHeading, $showCompare) = @_;

	$self->SUPER::extractComparison($subHeading, $showCompare);
}

1;
