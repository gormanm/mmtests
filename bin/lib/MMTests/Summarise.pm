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

sub typeToPreferredVal() {
	my ($self, $type) = @_;

	if ($type == DataTypes::DATA_TIME_SECONDS ||
	    $type == DataTypes::DATA_TIME_NSECONDS ||
	    $type == DataTypes::DATA_TIME_MSECONDS ||
	    $type == DataTypes::DATA_TIME_USECONDS ||
	    $type == DataTypes::DATA_TIME_CYCLES ||
	    $type == DataTypes::DATA_BAD_ACTIONS) {
		return "Lower";
	}
	return "Higher";
}

sub getPreferredValue() {
	my ($self, $op) = @_;
	return $self->typeToPreferredVal($self->getDataType($op));
}

# If there's single data type for the module, use its direction even for
# ratio comparisons. Otherwise create ratios so that lower values are always
# preferred.
sub getRatioPreferredValue() {
	my $self = $_;

	if (defined($self->{_DataType})) {
		return $self->typeToPreferredVal($self->{_DataType});
	}
	return "Lower";
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
	my ($self, $operation, $sumop) = @_;
	my $value;

	($sumop, $value) = split("-", $sumop);
	# We don't bother to convert _mean here to appropriate mean type as
	# that is always based on preferred value anyway
	if (!defined(MMTests::Stat::stat_compare->{$sumop})) {
		if ($self->getPreferredValue($operation) eq "Higher") {
			return "pdiff";
		}
		return "pndiff";
	}
	return MMTests::Stat::stat_compare->{$sumop};
}

sub getStatName() {
	my ($self, $operation, $sumop) = @_;
	my ($opname, $value, $mean);

	if ($self->getPreferredValue($operation) eq "Higher") {
		$mean = "hmean";
	} else {
		$mean = "amean";
	}
	$sumop =~ s/^_mean/$mean/;
	$sumop =~ s/^_value/$self->{_Opname}/;

	if (defined(MMTests::Stat::stat_names->{$sumop})) {
		return MMTests::Stat::stat_names->{$sumop};
	}
	($opname, $value) = split("-", $sumop);
	$opname .= "-";
	if (!defined(MMTests::Stat::stat_names->{$opname})) {
		return $sumop;
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

sub runStatFunc
{
	my ($self, $operation, $func, $dataref) = @_;
	my ($mean, $arg);

	# $dataref is expected to be already sorted in appropriate order
	if ($self->getPreferredValue($operation) eq "Higher") {
		$mean = "hmean";
	} else {
		$mean = "amean";
	}
	# Subselection means are a bit special...
	if ($func eq "_mean-sub") {
		return calc_submean_ci($mean, $dataref);
	}
	# calc_submean_ci returns two element list, thus following 'submeanci'
	# has nothing to do and must return empty list. This is because
	# calculating submean is relatively expensive and we get CI with it
	# as well so it would be stupid to recompute it again.
	if ($func eq "submeanci") {
		return ();
	}
	if ($func eq "_value") {
		return $dataref->[0];
	}
	$func =~ s/^_mean/$mean/;

	($func, $arg) = split("-", $func);
	# Percentiles are trivial, no need to copy the whole data array for them
	if ($func eq "percentile") {
		my $nr_elements = scalar(@{$dataref});
		my $count = int ($nr_elements * $arg / 100);

		$count = $count < 1 ? 1 : $count;
		return $dataref->[$count-1];
	}
	$func = "calc_$func";
	# Another argument to statistics function?
	if ($arg > 0) {
		# So far all numeric arguments are just a percentage of data to
		# compute function from.
		my $nr_elements = scalar(@{$dataref});
		my $count = int ($nr_elements * $arg / 100);
		$count = $count < 1 ? 1 : $count;
		my @data = @{$dataref}[0..($count-1)];

		no strict "refs";
		return &$func(\@data);
	}
	no strict "refs";
	return &$func($dataref);
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = $self->summaryOps($subHeading);
	my %data = %{$self->dataByOperation()};

	my %summary;
	my %significance;
	foreach my $operation (@_operations) {
		my @units;

		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}

		if ($self->getPreferredValue($operation) eq "Lower") {
			@units = sort { $a <=> $b} @units;
		} else {
			@units = sort { $b <=> $a} @units;
		}

		$summary{$operation} = [];
		foreach my $func (@{$self->{_SummaryStats}}) {
			my @values = $self->runStatFunc($operation, $func,
							\@units);
			foreach my $value (@values) {
				if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
					push @{$summary{$operation}}, $value;
				}
			}
		}

		$significance{$operation} = [];

		my $mean = $self->runStatFunc($operation, "_mean", \@units);
		push @{$significance{$operation}}, $mean;

		my $stderr = calc_stddev(\@units);
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
	my %summary;
	my %summaryCILen;
	foreach my $operation (@_operations) {
		my @units;
		my @values;

		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}

		if ($self->getPreferredValue($operation) eq "Lower") {
			@units = sort { $a <=> $b} @units;
		} else {
			@units = sort { $b <=> $a} @units;
		}

		foreach my $func (@{$self->{_RatioSummaryStat}}) {
			no strict "refs";
			push @values, $self->runStatFunc($operation, $func,
				\@units);
		}

		if (($values[0] ne "NaN" && $values[0] ne "nan") ||
		    $self->{_FilterNaN} != 1) {
			$summary{$operation} = [$values[0]];
			if ($#values == 1 && $values[1] ne "NaN") {
				$summaryCILen{$operation} = $values[1];
			}
		}
	}
	$self->{_SummaryData} = \%summary;
	$self->{_SummaryCILen} = \%summaryCILen if %summaryCILen;

	return 1;
}

1;
