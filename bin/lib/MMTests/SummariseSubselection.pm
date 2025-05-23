# SummariseSubselection.pm
package MMTests::SummariseSubselection;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::DataTypes;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_SummaryStats} = [ "min", "_mean", "_mean-50", "_mean-90", "_mean-95", "_mean-99", "stddev-_mean",
		"coeffvar-_mean", "max", "submean-_mean", "submeanci-_mean" ];
	$self->{_RatioSummaryStat} = [ "submean-_mean", "submeanci_low-_mean",
				       "submeanci_high-_mean" ];
	$self->{_RatioCompareOp} = "cidiff";
	$self->SUPER::initialise($subHeading);
}

1;
