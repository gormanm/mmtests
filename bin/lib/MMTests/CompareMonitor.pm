# CompareMonitor.pm
package MMTests::CompareMonitor;
use MMTests::Compare;
use MMTests::Stat;
our @ISA = qw(MMTests::Compare);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareMonitor",
	};
	bless $self, $class;
	return $self;
}

sub _generateTitleTable() {
	my ($self) = @_;
	my @titleTable;

	my @extractModules = @{$self->{_ExtractModules}};
	my @summaryHeaders = @{$extractModules[0]->{_SummaryHeaders}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my @baseline = @{$baselineRef};

	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		for (my $row = 0; $row <= $#baseline; $row++) {
			push @titleTable, [$summaryHeaders[$column],
				   	$baseline[$row][0]];
		}
	}

	$self->{_TitleTable} = \@titleTable;
}

sub _generateComparisonTable() {
	my ($self, $subHeading, $showCompare) = @_;
	my @resultsTable;
	my @compareTable;
	my @compareRatioTable;
	my @normCompareTable;

	my @extractModules = @{$self->{_ExtractModules}};
	my @summaryHeaders = @{$extractModules[0]->{_SummaryHeaders}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my @baseline = @{$baselineRef};
	my $baseCILenRef = $extractModules[0]->{_SummaryCILen};
	my @baseCILen = @{$baseCILenRef // []};

	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		for (my $row = 0; $row <= $#baseline; $row++) {
			my @data;
			my @compare;
			my @ratio;
			my @normcmp;
			my $compareOp = "pndiff";
			my $ratioCompareOp = "sdiff";

			# Some monitors are based on SummariseMultiops
			if (defined($extractModules[0]->{_SummaryStats})) {
				$compareOp = $extractModules[0]->getStatCompareFunc($column);
			}
			for (my $module = 0; $module <= $#extractModules; $module++) {
				no strict "refs";
				my $summaryRef = $extractModules[$module]->{_SummaryData};
				my @summary = @{$summaryRef};
				my $summaryCILenRef = $extractModules[$module]->{_SummaryCILen};
				my @summaryCILen = @{$summaryCILenRef};

				if ($summary[$row][$column] eq "") {
					$summary[$row][$column] = "NaN";
				}
				if ($summary[$row][$column] != -1 && $summary[$row][$column] ne "NaN" && $baseline[$row][$column] != -1) {
					push @data, $summary[$row][$column];
					push @compare, &$compareOp($summary[$row][$column], $baseline[$row][$column]);
					push @ratio,   rdiff($summary[$row][$column], $baseline[$row][$column]);
					if ($baseCILenRef) {
						my $sdiff_val;

						$sdiff_val = &$ratioCompareOp($summary[$row][$column], $summaryCILen[$row], $baseline[$row][$column], $baseCILen[$row]);
						if ($sdiff_val eq "NaN" || $sdiff_val eq "nan") {
							$sdiff_val = 0;
						}
						print "Comparing ($ratioCompareOp) $summary[$row][$column] $summaryCILen[$row] $baseline[$row][$column] $baseCILen[$row]: $sdiff_val\n";
						push @normcmp, $sdiff_val;
					}
				} else {
					push @data, 0;
					push @compare, 0;
					push @ratio, 1;
					push @normcmp, 0;
				}
			}
			push @resultsTable, [@data];
			push @compareTable, [@compare];
			push @compareRatioTable, [@ratio];
			push @normCompareTable, [@normcmp];
		}
	}

	my @geomean;
	my @normcmpmean;
	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		for (my $module = 0; $module <= $#extractModules; $module++) {
			my @units;
			for (my $row = 0; $row <= $#baseline; $row++) {
				push @units, $normCompareTable[$row][$module];
			}
			push @normcmpmean, [ calc_mean(@units), calc_min(@units), calc_max(@units) ];

			@units = ();
			for (my $row = 0; $row <= $#baseline; $row++) {
				if ($compareRatioTable[$row][$module] eq "NaN" ||
				    $compareRatioTable[$row][$module] eq "") {
					push @units, 1;
				} elsif ($compareRatioTable[$row][$module] != 0) {
					push @units, $compareRatioTable[$row][$module];
				} else {
					push @units, 0.00001;
				}
			}
			push @geomean, calc_geomean(@units);
		}
	}

	$self->{_ResultsTable} = \@resultsTable;
	$self->{_ResultsNormalizedTable} = \@normCompareTable if $baseCILenRef;
	$self->{_NormalizedDiffStatsTable} = \@normcmpmean if $baseCILenRef;
	$self->{_ResultsRatioTable} = \@compareRatioTable;
	$self->{_GeometricMeanTable} = \@geomean;

	if ($showCompare) {
		$self->{_CompareTable} = \@compareTable;
	}
}

# Construct final table for printing
sub _generateRenderRatioTable() {
	my ($self) = @_;
	my @finalTable;
	my @formatTable;
	my @compareTable;

	my @titleTable = @{$self->{_TitleTable}};
	my @resultsTable = @{$self->{_ResultsRatioTable}};
	my @normResultsTable = @{$self->{_ResultsNormalizedTable}} if exists $self->{_ResultsNormalizedTable};
	my $fieldLength = $self->{_FieldLength};
	my $compareLength = 0;
	my $precision = 2;
	if ($self->{_Precision}) {
		$precision = $self->{_Precision};
	}
	my @compareTable;
	if (defined $self->{_CompareTable}) {
		@compareTable = @{$self->{_CompareTable}};
		$compareLength = $self->{_CompareLength};
	}

	my @extractModules = @{$self->{_ExtractModules}};
	my @summaryHeaders = @{$extractModules[0]->{_SummaryHeaders}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my @baseline = @{$baselineRef};

	# Format string for columns
	my $maxLength = 0;
	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		my $len = length($summaryHeaders[$column]);
		if ($len > $maxLength) {
			$maxLength = $len;
		}
	}
	push @formatTable, "%-${maxLength}s";
	$self->{_OperationLength} = $maxLength;

	# Format string for source table rows
	$maxLength = 0;
	for (my $row = 0; $row <= $#baseline; $row++) {
		my $length = length($baseline[$row][0]);
		if ($length > $maxLength) {
			$maxLength = $length;
		}
	}
	push @formatTable, " %-${maxLength}s";
	$self->{_OperationLength} += $maxLength + 1;

	# Build column format table
	for (my $i = 0; $i <= $#{$resultsTable[0]}; $i++) {
		my $fieldFormat = "%${fieldLength}.${precision}f";
		if (defined $self->{_CompareTable}) {
			push @formatTable, ($fieldFormat, " (%${compareLength}.2f%%)", " (\%+${compareLength}.2fs)");
		} else {
			push @formatTable, ($fieldFormat, "");
		}
	}

	my $maxCols = 0;

	# Final comparison table
	for (my $row = 0; $row <= $#titleTable; $row++) {
		my @row;
		foreach my $elements ($titleTable[$row]) {
			foreach my $element (@{$elements}) {
				push @row, $element;
			}
		}

		if ($#{$resultsTable[$row]} > $maxCols) {
			$maxCols = $#{$resultsTable[$row]};
		}
		next if $#{$resultsTable[$row]} < $maxCols;

		for (my $i = 0; $i <= $#{$resultsTable[$row]}; $i++) {
			push @row, $resultsTable[$row][$i];
			if (defined $self->{_CompareTable}) {
				push @row, $compareTable[$row][$i];
			} else {
				push @row, [""];
			}
			if (defined $self->{_ResultsNormalizedTable}) {
				push @row, $normResultsTable[$row][$i] // 0;
			} else {
				push @row, [""];
			}
		}
		push @finalTable, [@row];
	}

	if (defined $self->{_NormalizedDiffStatsTable}) {
		# Stddev mean table
		my @ndiffTable = $self->{_NormalizedDiffStatsTable};
		my @extractModules = @{$self->{_ExtractModules}};
		my (@dmeanLine, @dminLine, @dmaxLine);
		push @dmeanLine, "Dmean";
		push @dminLine, "Dmin";
		push @dmaxLine, "Dmax";
		push @dmeanLine, $extractModules[0]->{_RatioPreferred};
		push @dminLine, $extractModules[0]->{_RatioPreferred};
		push @dmaxLine, $extractModules[0]->{_RatioPreferred};
		for (my $i = 0; $i <= $#{$ndiffTable[0]}; $i++) {
			push @dmeanLine, ($ndiffTable[0][$i][0], undef, undef);
			push @dminLine, ($ndiffTable[0][$i][1], undef, undef);
			push @dmaxLine, ($ndiffTable[0][$i][2], undef, undef);
		}
		push @finalTable, [@dmeanLine], [@dminLine], [@dmaxLine];
	}

	# Geometric mean table
	my @geomeanTable = $self->{_GeometricMeanTable};
	my @extractModules = @{$self->{_ExtractModules}};
	my @rowLine;
	push @rowLine, "Gmean";
	push @rowLine, $extractModules[0]->{_RatioPreferred};
	for (my $i = 0; $i <= $#{$geomeanTable[0]}; $i++) {
		push @rowLine, ($geomeanTable[0][$i], undef, undef);
	}
	push @finalTable, [@rowLine];

	$self->{_RenderTable} = \@finalTable;
	$self->{_FieldFormat} = \@formatTable;
}

# Construct final table for printing
sub _generateRenderTable() {
	my ($self, $printSignificance) = @_;
	my @finalTable;
	my @formatTable;
	my @compareTable;

	my @titleTable = @{$self->{_TitleTable}};
	my @resultsTable = @{$self->{_ResultsTable}};
	my $fieldLength = $self->{_FieldLength};
	my $compareLength = 0;
	my $precision = 2;
	if ($self->{_Precision}) {
		$precision = $self->{_Precision};
	}
	my @compareTable;
	if (defined $self->{_CompareTable}) {
		@compareTable = @{$self->{_CompareTable}};
		$compareLength = $self->{_CompareLength};
		if (! defined $compareLength) {
			$compareLength = 7;
		}
	}

	my @extractModules = @{$self->{_ExtractModules}};
	my @summaryHeaders = @{$extractModules[0]->{_SummaryHeaders}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my @baseline = @{$baselineRef};

	# Format string for columns
	my $maxLength = 0;
	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		my $len = length($summaryHeaders[$column]);
		if ($len > $maxLength) {
			$maxLength = $len;
		}
	}
	push @formatTable, "%-${maxLength}s";
	$self->{_OperationLength} = $maxLength;

	# Format string for source table rows
	my $separator = "";

	if ($self->{_OperationLength} > 0) {
		$separator = " ";
	}

	$maxLength = 0;
	for (my $row = 0; $row <= $#baseline; $row++) {
		my $length = length($baseline[$row][0]);
		if ($length > $maxLength) {
			$maxLength = $length;
		}
	}

	push @formatTable, $separator."%-${maxLength}s";
	$self->{_OperationLength} += $maxLength + length($separator);

	# Build column format table
	for (my $i = 0; $i <= $#{$resultsTable[0]}; $i++) {
		my $fieldFormat = "%${fieldLength}.${precision}f";
		if (defined $self->{_CompareTable}) {
			push @formatTable, ($fieldFormat, " (%${compareLength}.2f%%)");
		} else {
			push @formatTable, ($fieldFormat, "");
		}
	}

	# Final comparison table
	for (my $row = 0; $row <= $#titleTable; $row++) {
		my @rowLine;
		foreach my $elements ($titleTable[$row]) {
			foreach my $element (@{$elements}) {
				push @rowLine, $element;
			}
		}
		for (my $i = 0; $i <= $#{$resultsTable[$row]}; $i++) {
			push @rowLine, $resultsTable[$row][$i];
			if (defined $self->{_CompareTable}) {
				push @rowLine, $compareTable[$row][$i];
			} else {
				push @rowLine, [""];
			}
		}
		push @finalTable, [@rowLine];
	}

	$self->{_RenderTable} = \@finalTable;
	$self->{_FieldFormat} = \@formatTable;
}

sub extractComparison() {
	my ($self, $subHeading, $showCompare) = @_;

	$self->_generateTitleTable();
	$self->_generateComparisonTable($subHeading, $showCompare);
}

1;
