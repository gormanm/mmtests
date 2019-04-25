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
	$self->{_SummaryStats} = [ "min", "_mean", "stddev", "coeffvar", "max",
		"_mean-50", "_mean-95", "_mean-99" ];
	$self->{_SummaryHeaders} = [ "Min", $self->{_MeanName}, "Stddev", "CoeffVar", "Max", "B$self->{_MeanName}-50", "B$self->{_MeanName}-95", "B$self->{_MeanName}-99" ];
}

1;
