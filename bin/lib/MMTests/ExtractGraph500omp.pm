# ExtractGraph500omp.pm
package MMTests::ExtractGraph500omp;
use MMTests::ExtractGraph500common;
our @ISA = qw(MMTests::ExtractGraph500common);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractGraph500omp";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;

	$self->SUPER::initialise($subHeading);
}

1;
