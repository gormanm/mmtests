# SummariseMultiops.pm
package MMTests::SummariseMultiops;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::DataTypes;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_SummaryStats} = [ "min", "_mean", "stddev-_mean",
		"coeffvar-_mean", "max", "_mean-50", "_mean-95", "_mean-99" ];
	$self->{_RatioSummaryStat} = [ "_mean", "stddev-_mean" ];
	$self->SUPER::initialise($subHeading);
}

1;
