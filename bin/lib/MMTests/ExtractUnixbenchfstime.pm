# ExtractUnixbenchfstime.pm
package MMTests::ExtractUnixbenchfstime;
use MMTests::ExtractUnixbenchcommon;
our @ISA = qw(MMTests::ExtractUnixbenchcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractUnixbenchfstime";
	$self->{_PlotYaxis}  = DataTypes::LABEL_KBYTES_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($subHeading);
}

1;
