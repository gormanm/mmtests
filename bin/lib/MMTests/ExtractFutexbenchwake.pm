# ExtractFutexbenchwake.pm
package MMTests::ExtractFutexbenchwake;
use MMTests::ExtractFutexbenchcommon;
our @ISA = qw(MMTests::ExtractFutexbenchcommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractFutexbenchrequeue";
	$self->{_DataType}   = DataTypes::DATA_TIME_MSECONDS;
	$self->{_PlotType}   = "thread-errorlines";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
