# SummariseMonitor.pm
package MMTests::SummariseMonitor;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::DataTypes;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_SummaryStats} = [ "_mean", "max" ];
	$self->{_RatioSummaryStat} = [ "_mean", "stddev" ];
	$self->SUPER::initialise($subHeading);
}

1;
