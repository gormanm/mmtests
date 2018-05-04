# SummariseVariabletime.pm
package MMTests::SummariseVariabletime;
use MMTests::Extract;
use MMTests::Summarise;
use VMR::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);
	if ($self->{_RatioPreferred} eq "Lower") {
		$self->{_CompareOp} = "pndiff";
	} else {
		$self->{_CompareOp} = "pdiff";
	}
	$self->{_SummaryHeaders} = [ "Unit", "Min", "1st-qrtle", "2nd-qrtle", "3rd-qrtle", "Max-90%", "Max-95%", "Max-99%", "Max", "$self->{_MeanName}", "Stddev", "Coeff", "Best99%$self->{_MeanName}", "Best95%$self->{_MeanName}",  "Best90%$self->{_MeanName}", "Best75%$self->{_MeanName}", "Best50%$self->{_MeanName}", "Best25%$self->{_MeanName}" ];
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my %data = %{$self->dataByOperation()};

	if ($subHeading ne "") {
		$#_operations = 0;
		$_operations[0] = $subHeading;
	}

	my $meanOp = $self->getMeanFunc;
	my $selectOp = $self->getSelectionFunc();

	foreach my $operation (@_operations) {
		no strict  "refs";

		my @units;
		my @row;
		my $nrUnits=0;
		foreach my $row (@{$data{$operation}}) {
			$nrUnits++;
			push @units, @{$row}[1];
		}

		$self->{_SummaryHeaders} = [ "Unit", "Min",
		"1st-qrtle", "2nd-qrtle", "3rd-qrtle", "Max-90%",
		"Max-95%", "Max-99%", "Max", "$self->{_MeanName}",
		"Stddev", "Coeff", "Best99%$self->{_MeanName}",
		"Best95%$self->{_MeanName}",
		"Best90%$self->{_MeanName}",
		"Best75%$self->{_MeanName}",
		"Best50%$self->{_MeanName}",
		"Best25%$self->{_MeanName}" ];

		push @row, $operation;

		if ($nrUnits == 0) {
			# no data for $operation
			push @row, qw{NaN NaN NaN NaN NaN NaN NaN NaN
			NaN NaN NaN NaN NaN NaN NaN NaN NaN};
		} else {
			my $quartilesRef = calc_quartiles(@units);
			my @quartiles = @{$quartilesRef};
			push @row, calc_min(@units);
			push @row, $quartiles[1];
			push @row, $quartiles[2];
			push @row, $quartiles[3];
			push @row, $quartiles[90];
			push @row, $quartiles[95];
			push @row, $quartiles[99];
			push @row, $quartiles[4];
			push @row, &$meanOp(@units);
			push @row, calc_stddev(@units);
			push @row, calc_coeffvar(@units);
			push @row, &$meanOp(@{&$selectOp(99, \@units)});
			push @row, &$meanOp(@{&$selectOp(95, \@units)});
			push @row, &$meanOp(@{&$selectOp(90, \@units)});
			push @row, &$meanOp(@{&$selectOp(75, \@units)});
			push @row, &$meanOp(@{&$selectOp(50, \@units)});
			push @row, &$meanOp(@{&$selectOp(25, \@units)});
		}

		push @{$self->{_SummaryData}}, \@row;
	}

	return 1;
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my %data = %{$self->dataByOperation()};

	if ($subHeading ne "") {
		$#_operations = 0;
		$_operations[0] = $subHeading;
	}

	$self->{_SummaryHeaders} = [ "Time", "Ratio" ];

	foreach my $operation (@_operations) {

		my @units;
		my @row;

		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}
		my $quartilesRef = calc_quartiles(@units);
		my @quartiles = @{$quartilesRef};
		push @row, $operation;
		push @row, $quartiles[95];

		push @{$self->{_SummaryData}}, \@row;
	}

	return 1;
}

1;
