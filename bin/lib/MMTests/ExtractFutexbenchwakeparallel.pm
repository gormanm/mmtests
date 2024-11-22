# ExtractFutexbenchwakeparallel.pm
package MMTests::ExtractFutexbenchwakeparallel;
use MMTests::ExtractFutexbenchcommon;
our @ISA = qw(MMTests::ExtractFutexbenchcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFutexbenchwakeparallel";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_USECONDS;
	$self->{_PlotType}   = "thread-errorlines";

	$self->SUPER::initialise($subHeading);
}

1;
