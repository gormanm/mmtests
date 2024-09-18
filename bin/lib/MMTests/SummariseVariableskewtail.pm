# SummariseVariableskewtail.pm
package MMTests::SummariseVariableskewtail;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_SummaryStats} = [ "min", "percentile-50",
		"percentile-90",  "percentile-95", "percentile-99",
		"percentile-99.9", "percentile-99.99", "percentile-99.999",
		"percentile-99.9999", "percentile-99.99999",
		"max", "_mean", "stddev", "coeffvar" ];
	$self->{_RatioSummaryStat} = [ "percentile-99.999" ];
	$self->SUPER::initialise($subHeading);
}

1;
