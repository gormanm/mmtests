# ExtractUnixbenchsyscall.pm
package MMTests::ExtractUnixbenchsyscall;
use MMTests::ExtractUnixbenchcommon;
our @ISA = qw(MMTests::ExtractUnixbenchcommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractUnixbenchsyscall";
	$self->{_DataType}   = DataTypes::DATA_TIME_NSECONDS;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($reportDir, $testName);
}

1;
