# Summarise.pm
package MMTests::Summarise;
use MMTests::Extract;
use MMTests::DataTypes;
use MMTests::Stat;
our @ISA = qw(MMTests::Extract);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "Summarise",
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $plotType = "candlesticks";
	my $opName = "Ops";
	my @sumheaders;

	if (defined $self->{_Opname}) {
		$opName = $self->{_Opname};
	} else {
		$self->{_Opname} = $opName;
	}
	if (defined $self->{_PlotType}) {
		$plotType = $self->{_PlotType};
	} else {
		$self->{_PlotType} = $plotType;
	}

	if ($self->{_DataType} == DataTypes::DATA_TIME_SECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_NSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_MSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_USECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_CYCLES ||
	    $self->{_DataType} == DataTypes::DATA_BAD_ACTIONS) {
		$self->{_MeanName} = "Amean";
		$self->{_RatioPreferred} = "Lower";
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
	    $self->{_DataType} == DataTypes::DATA_SUCCESS_PERCENT ||
	    $self->{_DataType} == DataTypes::DATA_RATIO_SPEEDUP) {
		$self->{_MeanName} = "Hmean";
		$self->{_RatioPreferred} = "Higher";
	}

	$self->SUPER::initialise($reportDir, $testName);
	$self->{_FieldLength} = 12 if ($self->{_FieldLength} == 0);
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Type", "Sample", $opName ];
	$self->{_SummaryLength} = $self->{_FieldLength} + 4 if !defined $self->{_SummaryLength};
	for (my $header = 0; $header < scalar @{$self->{_SummaryStats}};
	     $header++) {
		push @sumheaders, $self->getStatName($header);
	}
	$self->{_SummaryHeaders} = \@sumheaders;
	$self->{_TestName} = $testName;
}

sub getSelectionFunc() {
	my ($self) = @_;

	if ($self->{_RatioPreferred} eq "Lower") {
		return "select_lowest";
	} elsif ($self->{_RatioPreferred} eq "Higher") {
		return "select_highest";
	} else {
		return "select_trim";
	}
}

sub getMeanFunc() {
	my ($self) = @_;

	if ($self->{_RatioPreferred} eq "Higher") {
		return "calc_harmmean";
	}
	return "calc_amean";
}

sub summaryOps() {
	my ($self, $subHeading) = @_;
	my @ops;

	foreach my $operation (@{$self->{_Operations}}) {
		if ($subHeading ne "" && !($operation =~ /^$subHeading.*/)) {
			next;
		}
		push @ops, $operation;
	}

	return @ops;
}

sub getStatCompareFunc() {
	my ($self, $opnum) = @_;
	my $op = $self->{_SummaryStats}->[$opnum];
	my $value;

	($op, $value) = split("-", $op);
	# We don't bother to convert _mean here to appropriate mean type as
	# that is always based on $self->{_RatioPreferred} anyway
	if (!defined(MMTests::Stat::stat_compare->{$op})) {
		if ($self->{_RatioPreferred} eq "Higher") {
			return "pdiff";
		}
		return "pndiff";
	}
	return MMTests::Stat::stat_compare->{$op};
}

sub getStatName() {
	my ($self, $opnum) = @_;
	my $op = $self->{_SummaryStats}->[$opnum];
	my ($opname, $value, $mean);

	if ($self->{_RatioPreferred} eq "Higher") {
		$mean = "hmean";
	} else {
		$mean = "amean";
	}
	$op =~ s/^_mean/$mean/;
	$op =~ s/^_value/$self->{_Opname}/;

	if (defined(MMTests::Stat::stat_names->{$op})) {
		return MMTests::Stat::stat_names->{$op};
	}
	($opname, $value) = split("-", $op);
	$opname .= "-";
	if (!defined(MMTests::Stat::stat_names->{$opname})) {
		return $op;
	}
	return sprintf(MMTests::Stat::stat_names->{$opname}, $value);
}

sub ratioSummaryOps() {
	my ($self, $subHeading) = @_;
	my @ratioops;
	my @ops;

	if (!defined($self->{_RatioOperations})) {
		@ratioops = @{$self->{_Operations}};
	} else {
		@ratioops = @{$self->{_RatioOperations}};
	}

	if ($subHeading eq "") {
		return @ratioops;
	}

	foreach my $operation (@ratioops) {
		if (!($operation =~ /^$subHeading.*/)) {
			next;
		}
		push @ops, $operation;
	}

	return @ops;
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my %data = %{$self->dataByOperation()};
	my @_operations = @{$self->{_Operations}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	if ($subHeading eq "") {
		$subHeading = $self->{_DefaultPlot}
	}


	if ($subHeading ne "") {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($self->{_ExactSubheading} == 1) {
				if (defined $self->{_ExactPlottype}) {
					$self->{_PlotType} = $self->{_ExactPlottype};
				}
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

	$self->sortResults();

	my $nr_headings = 0;
	foreach my $heading (@_operations) {
		my @index;
		my @units;
		my @row;
		my $samples = 0;

		foreach my $row (@{$data{$heading}}) {
			my $head = @{$row}[0];

			if ($self->{_PlotStripSubheading}) {
				if ($self->{_ClientSubheading} == 1) {
					$head =~ s/-$subHeading$//;
				} else {
					$head =~ s/^$subHeading-//;
				}
			}
			push @index, $head;
			push @units, @{$row}[1];
			$samples++;
		}

		$nr_headings++;
		if ($self->{_PlotType} =~ /simple.*/) {
			my $fake_samples = 0;

			if ($self->{_PlotType} =~ /simple-samples/) {
				$fake_samples = 1;
			}

			for ($samples = 0; $samples <= $#index; $samples++) {
				my $stamp = $index[$samples] - $index[0];
				if ($fake_samples) {
					$stamp = $samples;
				}

				# Use %d for integers to avoid strangely looking graphs
				if (int $index[$samples] != $index[$samples]) {
					printf("%-${fieldLength}.3f %${fieldLength}.3f\n", $stamp, $units[$samples]);
				} else {
					printf("%-${fieldLength}d %${fieldLength}.3f\n", $stamp, $units[$samples]);
				}
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
			for ($samples = 0; $samples <= $#units; $samples++) {
				printf("%-${fieldLength}s %${fieldLength}.3f\n",
					$heading, $units[$samples]);
			}
		}
	}
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = $self->summaryOps($subHeading);
	my %data = %{$self->dataByOperation()};

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

		my $stderr = calc_stddev(@units);
		push @{$significance{$operation}}, $stderr ne "NaN" ? $stderr : 0;

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
