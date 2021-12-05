# ExtractFutexbenchrequeuepi.pm
package MMTests::ExtractFutexbenchrequeuepi;
use MMTests::ExtractFutexbenchcommon;
our @ISA = qw(MMTests::ExtractFutexbenchcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFutexbenchrequeuepi";
	$self->{_DataType}   = DataTypes::DATA_TIME_MSECONDS;
	$self->{_PlotType}   = "thread-errorlines";

	$self->SUPER::initialise($subHeading);
}

1;
