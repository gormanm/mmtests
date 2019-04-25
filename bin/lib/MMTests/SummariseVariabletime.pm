# SummariseVariabletime.pm
package MMTests::SummariseVariabletime;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_SummaryStats} = [ "min", "percentile-25", "percentile-50",
		"percentile-75", "percentile-1", "percentile-5",
		"percentile-10", "percentile-90",  "percentile-95",
		"percentile-99", "max", "_mean", "stddev", "coeffvar",
		"_mean-99", "_mean-95", "_mean-90", "_mean-75", "_mean-50",
		"_mean-25" ];
	$self->{_RatioSummaryStat} = [ "percentile-95" ];
	$self->SUPER::initialise($reportDir, $testName);
}

1;
