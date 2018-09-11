# SummariseSubselection.pm
package MMTests::SummariseSubselection;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::DataTypes;
use VMR::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);
	if ($self->{_RatioPreferred} eq "Lower") {
		$self->{_CompareOps} = [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ];
	} else {
		$self->{_CompareOps} = [ "none", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff", "pdiff" ];
	}
	$self->{_SummaryHeaders} = [ "Op", "Min", $self->{_MeanName}, "Stddev", "Max", "Sub$self->{_MeanName}", "Sub$self->{_MeanName}CI" ];
	$self->{_RatioCompareOp} = "cidiff";
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my %data = %{$self->dataByOperation()};

	if ($subHeading ne "") {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($_operations[$index] =~ /^$subHeading.*/) {
				$index++;
				next;
			}
			splice(@_operations, $index, 1);
		}
	}

	foreach my $operation (@_operations) {
		my @units;
		my @row;

		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}

		push @row, $operation;
		my $funcName;
		foreach $funcName ("calc_min", $self->getMeanFunc, "calc_stddev", "calc_max") {
			no strict "refs";
			my $value = &$funcName(@units);
			if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
				push @row, $value;
			}
		}
		push @row, calc_submean_ci($self->{_MeanName}, \@units);
		if ($#row > 1) {
			push @{$self->{_SummaryData}}, \@row;
		}
	}

	return 1;
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my %data = %{$self->dataByOperation()};
	my %includeOps;

	$self->{_SummaryHeaders} = [ "Op", "Ratio" ];

	if (defined $self->{_MultiInclude}) {
		%includeOps = %{$self->{_MultiInclude}};
	}

	if ($subHeading ne "") {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($_operations[$index] =~ /^$subHeading.*/) {
				$index++;
				next;
			}
			splice(@_operations, $index, 1);
		}
	}
	if (%includeOps) {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($includeOps{$_operations[$index]} == 1) {
				$index++;
				next;
			}
			splice(@_operations, $index, 1);
		}
	}

	foreach my $operation (@_operations) {
		my @units;
		my @row;
		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}
		push @row, $operation;

		my $subMean;
		my $ciLen;

		($subMean, $ciLen) = calc_submean_ci($self->{_MeanName}, \@units);
		if (($subMean ne "NaN" && $subMean ne "nan") || $self->{_FilterNaN} != 1) {
			push @row, $subMean;
		}
		if ($#row > 0) {
			push @{$self->{_SummaryData}}, \@row;
			push @{$self->{_SummaryCILen}}, $ciLen;
		}
	}

	return 1;
}

1;
