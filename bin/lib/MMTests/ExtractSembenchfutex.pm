# ExtractSembenchfutex.pm
package MMTests::ExtractSembenchfutex;
use MMTests::ExtractSembenchcommon;
our @ISA = qw(MMTests::ExtractSembenchcommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractSembenchfutex";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_MSECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Threads";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
