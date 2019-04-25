# SummariseSubselection.pm
package MMTests::SummariseSubselection;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::DataTypes;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_SummaryStats} = [ "min", "_mean", "stddev", "coeffvar", "max",
		"_mean-sub", "submeanci" ];
	$self->{_RatioSummaryStat} = [ "_mean-sub", "submeanci" ];
	$self->{_RatioCompareOp} = "cidiff";
	$self->SUPER::initialise($reportDir, $testName);
}

1;
