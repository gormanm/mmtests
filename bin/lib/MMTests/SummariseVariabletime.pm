# SummariseVariabletime.pm
package MMTests::SummariseVariabletime;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $opName = "Ops";
	if (defined $self->{_Opname}) {
		$opName = $self->{_Opname};
	}

	$self->{_ModuleName} = "SummariseVariabletime";
	$self->SUPER::initialise();

	$self->{_FieldLength} = 12;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Type", "Sample", $self->{_Opname} ? $self->{_Opname} : "Ops" ];

	if ($self->{_DataType} == DataTypes::DATA_TIME_SECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_NSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_MSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_USECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_CYCLES ||
	    $self->{_DataType} == DataTypes::DATA_BAD_ACTIONS) {
		$self->{_MeanOp} = "calc_mean";
		$self->{_MeanOpBest} = "calc_lowest_mean";
		$self->{_MeanName} = "Amean";
		$self->{_RatioPreferred} = "Lower";
		$self->{_CompareOp} = "pndiff";
	}
	if ($self->{_DataType} == DataTypes::DATA_ACTIONS ||
	    $self->{_DataType} == DataTypes::DATA_ACTIONS_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_ACTIONS_PER_MINUTE ||
	    $self->{_DataType} == DataTypes::DATA_OPS_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_OPS_PER_MINUTE ||
	    $self->{_DataType} == DataTypes::DATA_KBYTES_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_MBYTES_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_MBITS_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_TRANS_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_TRANS_PER_MINUTE ||
	    $self->{_DataType} == DataTypes::DATA_SUCCESS_PERCENT) {
		$self->{_MeanOp} = "calc_harmmean";
		$self->{_MeanOpBest} = "calc_highest_harmmean";
		$self->{_MeanName} = "Hmean";
		$self->{_RatioPreferred} = "Higher";
		$self->{_CompareOp} = "pdiff";
	}

	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ "Unit", "Min", "1st-qrtle", "2nd-qrtle", "3rd-qrtle", "Max-90%", "Max-95%", "Max-99%", "Max", "$self->{_MeanName}", "Stddev", "Coeff", "Best99%$self->{_MeanName}", "Best95%$self->{_MeanName}",  "Best90%$self->{_MeanName}", "Best75%$self->{_MeanName}", "Best50%$self->{_MeanName}", "Best25%$self->{_MeanName}" ];
	$self->{_SummariseColumn} = 2;
	$self->{_TestName} = $testName;
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	$subHeading = $self->{_DefaultPlot} if $subHeading eq "";
	$subHeading =~ s/\s+//g;

	my @units;
	my @index;
	my @row;
	my $samples = 0;
	foreach my $row (@data) {
		@{$row}[0] =~ s/\s+//g;
		if (@{$row}[0] eq $subHeading || $self->{_PlotType} eq "simple") {
			push @index, @{$row}[1];
			push @units, @{$row}[2];
			$samples++;
		} elsif (@{$row}[0] eq $subHeading && $self->{_PlotType} eq "simple-filter") {
			push @index, @{$row}[1];
			push @units, @{$row}[2];
			$samples++;
		}

	}
	if ($self->{_PlotType} eq "simple" || $self->{_PlotType} eq "simple-filter") {
		for (my $samples = 0; $samples <= $#index; $samples++) {
			if (int $index[$samples] == $index[$samples]) {
				printf("%-${fieldLength}d %${fieldLength}.3f\n", $index[$samples] - $index[0], $units[$samples]);
			} else {
				printf("%-${fieldLength}f %${fieldLength}.3f\n", $index[$samples] - $index[0], $units[$samples]);
			}
		}
	} else {
		$self->_printCandlePlotData($fieldLength, @units);
	}
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my @data = @{$self->{_ResultData}};

	if ($subHeading ne "") {
		$#_operations = 0;
		$_operations[0] = $subHeading;
	}

	my $meanOp = $self->{_MeanOp};
	my $bestOp = $self->{_MeanOpBest};

	foreach my $operation (@_operations) {
		no strict  "refs";

		my @units;
		my @row;
		my $samples = 0;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$operation") {
				push @units, @{$row}[2];
				$samples++;
			}
		}

        $self->{_SummaryHeaders} = [ "Unit", "Min", "1st-qrtle", "2nd-qrtle", "3rd-qrtle", "Max-90%", "Max-95%", "Max-99%", "Max", "$self->{_MeanName}", "Stddev", "Coeff", "Best99%$self->{_MeanName}", "Best95%$self->{_MeanName}",  "Best90%$self->{_MeanName}", "Best75%$self->{_MeanName}", "Best50%$self->{_MeanName}", "Best25%$self->{_MeanName}" ];

		my $quartilesRef = calc_quartiles(@units);
		my @quartiles = @{$quartilesRef};
		push @row, $operation;
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
		push @row, &$bestOp(99, @units);
		push @row, &$bestOp(95, @units);
		push @row, &$bestOp(90, @units);
		push @row, &$bestOp(75, @units);
		push @row, &$bestOp(50, @units);
		push @row, &$bestOp(25, @units);

		push @{$self->{_SummaryData}}, \@row;
	}

	return 1;
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my @data = @{$self->{_ResultData}};

	if ($subHeading ne "") {
		$#_operations = 0;
		$_operations[0] = $subHeading;
	}

	$self->{_SummaryHeaders} = [ "Time", "Ratio" ];

	foreach my $operation (@_operations) {

		my @units;
		my @row;
		my $samples = 0;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$operation") {
				push @units, @{$row}[2];
				$samples++;
			}
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
