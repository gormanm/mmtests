# ExtractUnixbenchfsbufferr.pm
package MMTests::ExtractUnixbenchfsbufferr;
use MMTests::ExtractUnixbenchcommon;
our @ISA = qw(MMTests::ExtractUnixbenchcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractUnixbenchfsbufferr";
	$self->{_PlotYaxis}  = DataTypes::LABEL_KBYTES_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "thread-errorlines";

	$self->SUPER::initialise($subHeading);
}

1;
