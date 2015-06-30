# ExtractFilelockperfposix.pm
package MMTests::ExtractFilelockperfposix;
use MMTests::ExtractFilelockperfcommon;
our @ISA = qw(MMTests::ExtractFilelockperfcommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractFilelockperfposix";
	$self->{_DataType}   = MMTests::Extract::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Tasks";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
