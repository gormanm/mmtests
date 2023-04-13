# ExtractHpagealloc.pm
package MMTests::ExtractHpagealloc;
use MMTests::SummariseVariableops;
our @ISA = qw(MMTests::SummariseVariableops);

use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractHpagealloc";
	$self->{_DataType} = DataTypes::DATA_TIME_MSECONDS,
	$self->{_PlotType} = "simple";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $input = $self->SUPER::open_log("$reportDir/hpagealloc.log");
	while (<$input>) {
		my @elements = split(/\s+/);

		$self->addData("Latency", $elements[4]);
	}
	close INPUT;
}
1;
