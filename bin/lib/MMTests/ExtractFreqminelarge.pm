# ExtractFreqminelarge.pm
package MMTests::ExtractFreqminelarge;
use MMTests::ExtractFreqminecommon;
our @ISA = qw(MMTests::ExtractFreqminecommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractFreqminelarge";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Threads";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
