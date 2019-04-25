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

	$self->{_SummaryStats} = [ "min", "_mean", "stddev", "coeffvar", "max",
		"_mean-50", "_mean-95", "_mean-99" ];
	$self->{_RatioSummaryStat} = [ "_mean", "stddev" ];
	$self->SUPER::initialise($reportDir, $testName);
}

1;
