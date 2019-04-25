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

	$self->SUPER::initialise($reportDir, $testName);
	$self->{_SummaryStats} = [ "min", "_mean", "stddev", "coeffvar", "max",
		"_mean-sub", "submeanci" ];
	$self->{_SummaryHeaders} = [ "Min", $self->{_MeanName}, "Stddev", "Max", "Sub$self->{_MeanName}", "Sub$self->{_MeanName}CI" ];
	$self->{_RatioCompareOp} = "cidiff";
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = $self->summaryOps($subHeading);
	my %data = %{$self->dataByOperation()};

	my %summary;
	foreach my $operation (@_operations) {
		my @units;
		my @row;

		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}

		my $funcName;
		$summary{$operation} = [];
		foreach $funcName ("calc_min", $self->getMeanFunc, "calc_stddev", "calc_max") {
			no strict "refs";
			my $value = &$funcName(@units);
			if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
				push @{$summary{$operation}}, $value;
			}
		}
		push @{$summary{$operation}}, calc_submean_ci($self->{_MeanName}, \@units);
	}
	$self->{_SummaryData} = \%summary;

	return 1;
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = $self->ratioSummaryOps($subHeading);
	my %data = %{$self->dataByOperation()};

	$self->{_SummaryHeaders} = [ "Ratio" ];

	my %summary;
	my %summaryCILen;
	foreach my $operation (@_operations) {
		my @units;
		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}
		my $subMean;
		my $ciLen;
		($subMean, $ciLen) = calc_submean_ci($self->{_MeanName}, \@units);
		if (($subMean ne "NaN" && $subMean ne "nan") || $self->{_FilterNaN} != 1) {
			$summary{$operation} = [$subMean];
			$summaryCILen{$operation} = $ciLen;
		}
	}
	$self->{_SummaryData} = \%summary;
	$self->{_SummaryCILen} = \%summaryCILen;

	return 1;
}

1;
