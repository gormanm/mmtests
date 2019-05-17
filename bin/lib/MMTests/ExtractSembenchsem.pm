# ExtractSembenchsem.pm
package MMTests::ExtractSembenchsem;
use MMTests::ExtractSembenchcommon;
our @ISA = qw(MMTests::ExtractSembenchcommon);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSembenchsem";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($subHeading);
}

1;
