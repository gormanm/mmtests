# ExtractWisposixsems.pm
package MMTests::ExtractWisposixsems;
use MMTests::ExtractWiscommon;
our @ISA = qw(MMTests::ExtractWiscommon);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractWisposixsems";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Threads";

	$self->SUPER::initialise($reportDir, $testName);
}

1;
