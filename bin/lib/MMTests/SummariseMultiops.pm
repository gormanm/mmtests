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
	if ($self->{_RatioPreferred} eq "Lower") {
		$self->{_CompareOps} = [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ];
	} else {
		$self->{_CompareOps} = [ "pdiff", "pdiff", "pndiff", "pndiff", "pdiff", "pdiff", "pdiff", "pdiff", ];
	}
	$self->{_SummaryHeaders} = [ "Min", $self->{_MeanName}, "Stddev", "CoeffVar", "Max", "B$self->{_MeanName}-50", "B$self->{_MeanName}-95", "B$self->{_MeanName}-99" ];
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

	my %summary;
	my %significance;
	foreach my $operation (@_operations) {
		my @units;
		my @row;

		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}

		my $funcName;
		$summary{$operation} = [];
		foreach $funcName ("calc_min", $self->getMeanFunc, "calc_stddev", "calc_coeffvar", "calc_max") {
			no strict "refs";
			my $value = &$funcName(@units);
			if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
				push @{$summary{$operation}}, $value;
			}
		}
		$funcName = $self->getMeanFunc;
		my $selectFunc = $self->getSelectionFunc();
		foreach my $i (50, 95, 99) {
			no strict "refs";
			my $value = &$funcName(@{&$selectFunc($i, \@units)});
			if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
				push @{$summary{$operation}}, $value;
			}
		}

		$significance{$operation} = [];

		$funcName = $self->getMeanFunc;
		my $mean;
		{
			no strict "refs";
			$mean = &$funcName(@units);
		}
		push @{$significance{$operation}}, $mean;
		push @{$significance{$operation}}, calc_stddev(@units);
		push @{$significance{$operation}}, $#units+1;

		if ($self->{_SignificanceLevel}) {
			push @{$significance{$operation}}, $self->{_SignificanceLevel};
		} else {
			push @{$significance{$operation}}, 0.10;
		}
	}
	$self->{_SummaryData} = \%summary;
	$self->{_SignificanceData} = \%significance;

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
		my $value;
		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}
		{
			no strict "refs";
			my $funcName = $self->getMeanFunc();
			$value = &$funcName(@units);
		}
		if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
			$summary{$operation} = [$value];
			if (!$self->{_SuppressDmean}) {
				$summaryCILen{$operation} = calc_stddev(@units);
			}
		}
	}
	$self->{_SummaryData} = \%summary;
	# we rely on _SummaryCILen being undef to honor _SuppressDmean
	$self->{_SummaryCILen} = \%summaryCILen if %summaryCILen;

	return 1;
}

1;
