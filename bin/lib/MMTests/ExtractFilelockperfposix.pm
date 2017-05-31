# ExtractFilelockperfposix.pm
package MMTests::ExtractFilelockperfposix;
use MMTests::ExtractFilelockperfcommon;
our @ISA = qw(MMTests::ExtractFilelockperfcommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractFilelockperfposix";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Tasks";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
