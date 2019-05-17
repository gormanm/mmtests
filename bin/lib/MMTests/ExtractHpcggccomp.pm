# ExtractHpcggccomp.pm
package MMTests::ExtractHpcggccomp;
use MMTests::ExtractHpcgcommon;
our @ISA = qw(MMTests::ExtractHpcgcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractHpcggccomp";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;

	$self->SUPER::initialise($subHeading);
}

1;
