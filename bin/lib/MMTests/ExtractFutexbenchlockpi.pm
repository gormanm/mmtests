# ExtractFutexbenchlockpi.pm
package MMTests::ExtractFutexbenchlockpi;
use MMTests::ExtractFutexbenchcommon;
our @ISA = qw(MMTests::ExtractFutexbenchcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFutexbenchlockpi";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "thread-errorlines";

	$self->SUPER::initialise($subHeading);
}

1;
