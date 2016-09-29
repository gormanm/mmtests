# ExtractUnixbenchfsdiskr.pm
package MMTests::ExtractUnixbenchfsdiskr;
use MMTests::ExtractUnixbenchcommon;
our @ISA = qw(MMTests::ExtractUnixbenchcommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractUnixbenchfsdiskr";
	$self->{_DataType}   = MMTests::Extract::DATA_KBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Threads";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
