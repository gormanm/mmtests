# ExtractHpcggccompmpi.pm
package MMTests::ExtractHpcggccompmpi;
use MMTests::ExtractHpcgcommon;
our @ISA = qw(MMTests::ExtractHpcgcommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractHpcggccompmpi";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;

	$self->SUPER::initialise($reportDir, $testName);
}

1;
