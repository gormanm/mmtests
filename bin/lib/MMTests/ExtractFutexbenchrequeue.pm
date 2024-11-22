# ExtractFutexbenchrequeue.pm
package MMTests::ExtractFutexbenchrequeue;
use MMTests::ExtractFutexbenchcommon;
our @ISA = qw(MMTests::ExtractFutexbenchcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFutexbenchrequeue";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_MSECONDS;
	$self->{_PlotType}   = "thread-errorlines";

	$self->SUPER::initialise($subHeading);
}

1;
