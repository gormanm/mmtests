# SummariseMultiops.pm
package MMTests::SummariseMultiops;
use MMTests::Extract;
use MMTests::DataTypes;
use VMR::Stat;
our @ISA = qw(MMTests::Extract);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "SummariseMultiops",
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $plotType = "candlesticks";
	my $opName = "Ops";
	if (defined $self->{_Opname}) {
		$opName = $self->{_Opname};
	}
	if (defined $self->{_PlotType}) {
		$plotType = $self->{_PlotType};
	}
	$self->{_Opname} = $opName;
	$self->{_PlotType} = $plotType;

	if ($self->{_DataType} == DataTypes::DATA_TIME_SECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_NSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_MSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_USECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_CYCLES ||
	    $self->{_DataType} == DataTypes::DATA_BAD_ACTIONS) {
		$self->{_MeanOp} = "calc_mean";
		$self->{_MeanName} = "Amean";
		$self->{_RatioPreferred} = "Lower";
		$self->{_CompareOps} = [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ];
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
		$self->{_MeanName} = "Hmean";
		$self->{_RatioPreferred} = "Higher";
		$self->{_CompareOps} = [ "none", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff" ];
	}

	$self->SUPER::initialise($reportDir, $testName);
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Type", "Sample", $self->{_Opname} ? $self->{_Opname} : "Ops" ];
	$self->{_SummaryLength} = $self->{_FieldLength} + 4 if !defined $self->{_SummaryLength};
	if ($self->{_Variable} == 1) {
		$self->{_SummaryHeaders} = [ "Unit", "Min", "1st-qrtle", "2nd-qrtle", "3rd-qrtle", "Max-90%", "Max-93%", "Max-95%", "Max-99%", "Max", "Best99%Mean", "Best95%Mean", "Best90%Mean", "Best50%Mean", "Best10%Mean", "Best5%Mean", "Best1%Mean" ];
	} else {
		$self->{_SummaryHeaders} = [ "Op", "Min", $self->{_MeanName}, "Stddev", "CoeffVar", "Max" ];
	}
	$self->{_SummariseColumn} = 2;
	$self->{_TestName} = $testName;
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my @_operations = @{$self->{_Operations}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	if ($subHeading ne "") {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($self->{_ExactSubheading} == 1) {
				$self->{_PlotType} = $self->{_ExactPlottype};
				if ($_operations[$index] eq "$subHeading") {
					$index++;
					next;
				}
			} elsif ($self->{_ClientSubheading} == 1) {
				if ($_operations[$index] =~ /.*-$subHeading$/) {
					$index++;
					next;
				}
			} else {
				if ($_operations[$index] =~ /^$subHeading.*/) {
					$index++;
					next;
				}
			}
			splice(@_operations, $index, 1);
		}
	}

	my $nr_headings = 0;
	foreach my $heading (@_operations) {
		my @index;
		my @units;
		my @row;
		my $samples = 0;
		$heading =~ s/\s//g;
		foreach my $row (@data) {
			@{$row}[0] =~ s/\s+//g;
			if (@{$row}[0] eq $heading) {
				push @index, @{$row}[1];
				push @units, @{$row}[2];
				$samples++;
			}
		}

		$nr_headings++;
		if ($self->{_PlotType} eq "simple") {
			my @data = @{$self->{_ResultData}};
			for ($samples = 0; $samples <= $#index; $samples++) {
				printf("%-${fieldLength}d %${fieldLength}.3f\n", $index[$samples] - $index[0], $units[$samples]);
			}
		} elsif ($self->{_PlotType} eq "candlesticks") {
			printf "%-${fieldLength}s ", $heading;
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "operation-candlesticks") {
			printf "%d %-${fieldLength}s ", $nr_headings, $heading;
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "client-candlesticks") {
			$heading =~ s/.*-//;
			printf "%-${fieldLength}s ", $heading;
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "single-candlesticks") {
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "client-errorbars") {
			$heading =~ s/.*-//;
			printf "%-${fieldLength}s ", $heading;
			$self->_printErrorBarData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "client-errorlines") {
			if ($self->{_ClientSubheading} == 1) {
				$heading =~ s/-.*//;
			} else {
				$heading =~ s/.*-//;
			}
			printf "%-${fieldLength}s ", $heading;
			$self->_printErrorBarData($fieldLength, @units);
		} elsif ($self->{_PlotType} =~ "histogram") {
			my @data = @{$self->{_ResultData}};
			foreach my $row (@data) {
				printf("%-${fieldLength}s %${fieldLength}.3f\n", @{$row}[0], @{$row}[2]);
			}
		}
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
		my $samples = 0;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$operation") {
				push @units, @{$row}[2];
				$samples++;
			}
		}

		if ($self->{_Variable} == 1) {
			my $quartilesRef = calc_quartiles(@units);
			my @quartiles = @{$quartilesRef};
			push @row, $operation;
			push @row, calc_min(@units);
			push @row, $quartiles[1];
			push @row, $quartiles[2];
			push @row, $quartiles[3];
			push @row, $quartiles[90];
			push @row, $quartiles[93];
			push @row, $quartiles[95];
			push @row, $quartiles[99];
			push @row, $quartiles[4];
			push @row, calc_highest_mean(99, @units);
			push @row, calc_highest_mean(95, @units);
			push @row, calc_highest_mean(90, @units);
			push @row, calc_highest_mean(50, @units);
			push @row, calc_highest_mean(10, @units);
			push @row, calc_highest_mean(5, @units);
			push @row, calc_highest_mean(1, @units);

			push @{$self->{_SummaryData}}, \@row;
		} else {
			push @row, $operation;
			foreach my $funcName ("calc_min", $self->{_MeanOp}, "calc_stddev", "calc_coeffvar", "calc_max") {
				no strict "refs";
				my $value = &$funcName(@units);
				if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
					push @row, $value;
				}
			}
			if ($#row > 1) {
				push @{$self->{_SummaryData}}, \@row;
			}
		}
	}

	return 1;
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my @data = @{$self->{_ResultData}};
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
		my $samples = 0;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$operation") {
				push @units, @{$row}[2];
				$samples++;
			}
		}
		push @row, $operation;
		foreach my $funcName ($self->{_MeanOp}) {
			no strict "refs";
			my $value = &$funcName(@units);
			if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
				push @row, $value;
			}
		}
		if ($#row > 0) {
			push @{$self->{_SummaryData}}, \@row;
			if (!$self->{_SuppressDmean}) {
				push @{$self->{_SummaryStdDevs}}, calc_stddev(@units);
			}
		}
	}

	return 1;
}

1;
