# ExtractSembenchsem.pm
package MMTests::ExtractSembenchsem;
use MMTests::ExtractSembenchcommon;
our @ISA = qw(MMTests::ExtractSembenchcommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSembenchsem";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($reportDir, $testName);
}

1;
