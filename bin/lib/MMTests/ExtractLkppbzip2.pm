# ExtractLkppbzip2.pm
package MMTests::ExtractLkppbzip2;
use MMTests::ExtractLkpthroughput;
our @ISA = qw(MMTests::ExtractLkpthroughput);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractLkppbzip2";
	$self->{_DataType}   = MMTests::Extract::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Threads";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
