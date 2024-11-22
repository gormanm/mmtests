# ExtractSembenchsem.pm
package MMTests::ExtractSembenchsem;
use MMTests::ExtractSembenchcommon;
our @ISA = qw(MMTests::ExtractSembenchcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSembenchsem";
	$self->{_PlotYaxis}  = DataTypes::LABEL_OPS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($subHeading);
}

1;
