# ExtractIpcscaleposixsempp.pm
package MMTests::ExtractIpcscaleposixsempp;
use MMTests::ExtractIpcscalecommon;
our @ISA = qw(MMTests::ExtractIpcscalecommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractIpcscaleposixsempp";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Threads";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
