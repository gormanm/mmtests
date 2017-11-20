# SummariseMultiops.pm
package MMTests::SummariseMultiops;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::DataTypes;
use VMR::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);
	$self->{_SummaryHeaders} = [ "Op", "Min", $self->{_MeanName}, "Stddev", "CoeffVar", "Max", "B$self->{_MeanName}-50", "B$self->{_MeanName}-95", "B$self->{_MeanName}-99" ];
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
		foreach $funcName ("calc_min", $self->getMeanFunc, "calc_stddev", "calc_coeffvar", "calc_max") {
			no strict "refs";
			my $value = &$funcName(@units);
			if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
				push @row, $value;
			}
		}
		$funcName = $self->getMeanFunc;
		my $selectFunc = $self->getSelectionFunc();
		foreach my $i (50, 95, 99) {
			no strict "refs";
			my $value = &$funcName(@{&$selectFunc($i, \@units)});
			if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
				push @row, $value;
			}
		}
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
				$index++
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
		foreach my $funcName ($self->getMeanFunc) {
			no strict "refs";
			my $value = &$funcName(@units);
			if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
				push @row, $value;
			}
		}
		if ($#row > 0) {
			push @{$self->{_SummaryData}}, \@row;
			if (!$self->{_SuppressDmean}) {
				push @{$self->{_SummaryCILen}}, calc_stddev(@units);
			}
		}
	}

	return 1;
}

1;
