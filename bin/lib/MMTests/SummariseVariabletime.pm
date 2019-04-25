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
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = $self->ratioSummaryOps($subHeading);
	my %data = %{$self->dataByOperation()};

	$self->{_SummaryHeaders} = [ "Ratio" ];
	my %summary;

	foreach my $operation (@_operations) {

		my @units;
		my @row;

		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}
		my $quartilesRef = calc_quartiles(\@units);
		my @quartiles = @{$quartilesRef};
		$summary{$operation} = [$quartiles[95]];
	}
	$self->{_SummaryData} = \%summary;

	return 1;
}

1;
