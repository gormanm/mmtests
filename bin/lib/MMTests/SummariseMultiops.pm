# SummariseMultiops.pm
package MMTests::SummariseMultiops;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::DataTypes;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);
	if ($self->{_RatioPreferred} eq "Lower") {
		$self->{_CompareOps} = [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ];
	} else {
		$self->{_CompareOps} = [ "pdiff", "pdiff", "pndiff", "pndiff", "pdiff", "pdiff", "pdiff", "pdiff", ];
	}
	$self->{_SummaryHeaders} = [ "Min", $self->{_MeanName}, "Stddev", "CoeffVar", "Max", "B$self->{_MeanName}-50", "B$self->{_MeanName}-95", "B$self->{_MeanName}-99" ];
}

1;
