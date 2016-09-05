# ExtractUnixbenchfsbufferr.pm
package MMTests::ExtractUnixbenchfsbufferr;
use MMTests::ExtractUnixbenchcommon;
our @ISA = qw(MMTests::ExtractUnixbenchcommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractUnixbenchfsbufferr";
	$self->{_DataType}   = MMTests::Extract::DATA_KBYTES_PER_SECOND;
	$self->{_PlotType}   = "simple";
	$self->{_PlotXaxis}  = "Threads";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
