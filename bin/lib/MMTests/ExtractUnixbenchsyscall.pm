# ExtractUnixbenchsyscall.pm
package MMTests::ExtractUnixbenchsyscall;
use MMTests::ExtractUnixbenchcommon;
our @ISA = qw(MMTests::ExtractUnixbenchcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractUnixbenchsyscall";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_NSECONDS;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($subHeading);
}

1;
