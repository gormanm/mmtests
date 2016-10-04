# ExtractLkpplzip.pm
package MMTests::ExtractLkpplzip;
use MMTests::ExtractLkpthroughput;
our @ISA = qw(MMTests::ExtractLkpthroughput);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractLkpplzip";
	$self->{_DataType}   = MMTests::Extract::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Threads";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
