# Compare.pm
#
# This is base class description for modules that take summaries from
# the Extract classes and compare them with each other.

package MMTests::Compare;

use constant DATA_NONE                  => MMTests::Extract::DATA_NONE;
use constant DATA_TIME_SECONDS          => MMTests::Extract::DATA_TIME_SECONDS;
use constant DATA_TIME_NSECONDS         => MMTests::Extract::DATA_TIME_NSECONDS;
use constant DATA_TIME_USECONDS         => MMTests::Extract::DATA_TIME_USECONDS;
use constant DATA_TIME_MSECONDS         => MMTests::Extract::DATA_TIME_MSECONDS;
use constant DATA_TIME_CYCLES           => MMTests::Extract::DATA_TIME_CYCLES;
use constant DATA_ACTIONS               => MMTests::Extract::DATA_ACTIONS;
use constant DATA_ACTIONS_PER_SECOND    => MMTests::Extract::DATA_ACTIONS_PER_SECOND;
use constant DATA_ACTIONS_PER_MINUTE    => MMTests::Extract::DATA_ACTIONS_PER_MINUTE;
use constant DATA_BAD_ACTIONS		=> MMTests::Extract::DATA_BAD_ACTIONS;
use constant DATA_OPS_PER_SECOND        => MMTests::Extract::DATA_OPS_PER_SECOND;
use constant DATA_OPS_PER_MINUTE        => MMTests::Extract::DATA_OPS_PER_MINUTE;
use constant DATA_KBYTES_PER_SECOND	=> MMTests::Extract::DATA_KBYTES_PER_SECOND;
use constant DATA_MBYTES_PER_SECOND     => MMTests::Extract::DATA_MBYTES_PER_SECOND;
use constant DATA_MBITS_PER_SECOND      => MMTests::Extract::DATA_MBITS_PER_SECOND;
use constant DATA_TRANS_PER_SECOND      => MMTests::Extract::DATA_TRANS_PER_SECOND;
use constant DATA_TRANS_PER_MINUTE      => MMTests::Extract::DATA_TRANS_PER_MINUTE;
use constant DATA_SUCCESS_PERCENT       => MMTests::Extract::DATA_SUCCESS_PERCENT;

use VMR::Stat;
use VMR::Blessless qw(blessless);
use MMTests::PrintGeneric;
use MMTests::PrintHtml;
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName 	=> "Compare",
		_DataType	=> 0,
		_FieldHeaders	=> [],
		_ResultData	=> [],
		_FieldLength	=> 0,
		_Headers	=> [ "Base" ],
	};
	bless $self, $class;
	return $self;
}

sub TO_JSON() {
	my ($self) = @_;
	return blessless($self);
}

sub getModuleName() {
	my ($self) = @_;
	return $self->{_ModuleName};
}

sub initialise() {
	my ($self, $extractModulesRef) = @_;
	my (@fieldHeaders, @plotHeaders, @summaryHeaders);
	my ($fieldLength, $plotLength, $summaryLength);
	my $compareLength = 6;

	$self->{_ExtractModules} = $extractModulesRef;
	my @extractModules = @{$extractModulesRef};
	$self->{_DataType} = $extractModules[0]->{_DataType};
	$self->{_FieldLength} = $extractModules[0]->{_FieldLength};

	if ($self->{_DataType} == DATA_TIME_SECONDS ||
	    $self->{_DataType} == DATA_TIME_NSECONDS ||
	    $self->{_DataType} == DATA_TIME_USECONDS ||
	    $self->{_DataType} == DATA_TIME_MSECONDS ||
	    $self->{_DataType} == DATA_TIME_CYCLES) {
		$compareLength = 6;
		@fieldHeaders = ("Time", "Procs");
	}
	if ($self->{_DataType} == DATA_OPS_PER_SECOND) {
		if (!defined $self->{_CompareOps}) {
			$self->{_CompareOps} = [ "none", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff" ];
		}
	}
	if (($self->{_DataType} == DATA_TRANS_PER_SECOND || $self->{_DataType} == DATA_TRANS_PER_MINUTE) && $self->{_Variable} != 1) {
		if (!defined $self->{_CompareOps}) {
			$self->{_CompareOps} = [ "none", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff" ];
		}
	}
	if (!$self->{_FieldLength}) {
		$self->{_FieldLength}  = 12;
	}
	if (!$self->{_CompareLength}) {
		$self->{_CompareLength}  = $compareLength;
	}
	$self->{_FieldHeaders} = \@fieldHeaders;
}

sub setFormat() {
	my ($self, $format) = @_;

	if ($format eq "html") {
		$self->{_PrintHandler} = MMTests::PrintHtml->new(1);
	} else {
		$self->{_PrintHandler} = MMTests::PrintGeneric->new(1);
	}
}

sub prepareForRSummary($) {
}

sub printReportTop($) {
	my ($self) = @_;
	$self->{_PrintHandler}->printTop();
}

sub printReportBottom($) {
	my ($self) = @_;
	$self->{_PrintHandler}->printBottom();
}

sub printFieldHeaders() {
	my ($self) = @_;
	$self->{_PrintHandler}->printHeaders(
		$self->{_FieldLength}, $self->{_FieldHeaders},
		$self->{_FieldHeaderFormat});
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
	my @stddevTable;

	my @extractModules = @{$self->{_ExtractModules}};
	my @summaryHeaders = @{$extractModules[0]->{_SummaryHeaders}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my @baseline = @{$baselineRef};
	my $baseStdDevsRef = $extractModules[0]->{_SummaryStdDevs};
	my @baseStdDevs = @{$baseStdDevsRef // []};

	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		for (my $row = 0; $row <= $#baseline; $row++) {
			my @data;
			my @compare;
			my @ratio;
			my @stddev;
			my $compareOp = "pdiff";

			if ($self->{_DataType} == DATA_TIME_SECONDS ||
			    $self->{_DataType} == DATA_TIME_NSECONDS ||
			    $self->{_DataType} == DATA_TIME_USECONDS ||
			    $self->{_DataType} == DATA_TIME_MSECONDS ||
			    $self->{_DataType} == DATA_TIME_CYCLES) {
				$compareOp = "pndiff";
			}
			if (defined $self->{_CompareOps}) {
				$compareOp = $self->{_CompareOps}[$column];
			}
			if (defined $self->{_CompareOp}) {
				$compareOp = $self->{_CompareOp};
			}
			if (defined $extractModules[0]->{_CompareOpsRow} &&
				defined $extractModules[0]->{_CompareOpsRow}[$row]) {
				$compareOp = $extractModules[0]->{_CompareOpsRow}[$row];
			}
			if (defined $extractModules[0]->{_CompareLookup}{$baseline[$row][0]}) {
				$compareOp = $extractModules[0]->{_CompareLookup}{$baseline[$row][0]};
			}
			for (my $module = 0; $module <= $#extractModules; $module++) {
				no strict "refs";
				my $summaryRef = $extractModules[$module]->{_SummaryData};
				my @summary = @{$summaryRef};
				if ($summary[$row][$column] eq "") {
					$summary[$row][$column] = "NaN";
				}
				if ($summary[$row][$column] != -1 && $summary[$row][$column] ne "NaN" && $baseline[$row][$column] != -1) {
					push @data, $summary[$row][$column];
					push @compare, &$compareOp($summary[$row][$column], $baseline[$row][$column]);
					push @ratio,   rdiff($summary[$row][$column], $baseline[$row][$column]);
					if ($baseStdDevsRef) {
						my $sdiff_val = sdiff($summary[$row][$column], $baseline[$row][$column], $baseStdDevs[$row]);
						if ($sdiff_val eq "NaN" || $sdiff_val eq "nan") {
							$sdiff_val = 0;
						}
						push @stddev, $sdiff_val;
					}
				} else {
					push @data, 0;
					push @compare, 0;
					push @ratio, 1;
					push @stddev, 0;
				}
			}
			push @resultsTable, [@data];
			push @compareTable, [@compare];
			push @compareRatioTable, [@ratio];
			push @stddevTable, [@stddev];
		}
	}

	my @geomean;
	my @devmean;
	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		for (my $module = 0; $module <= $#extractModules; $module++) {
			my @units;
			for (my $row = 0; $row <= $#baseline; $row++) {
				push @units, $stddevTable[$row][$module];
			}
			push @devmean, [ calc_mean(@units), calc_min(@units), calc_max(@units) ];

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
	$self->{_ResultsStdDevTable} = \@stddevTable if $baseStdDevsRef;
	$self->{_StddevMeanTable} = \@devmean if $baseStdDevsRef;
	$self->{_ResultsRatioTable} = \@compareRatioTable;
	$self->{_GeometricMeanTable} = \@geomean;


	if ($showCompare) {
		$self->{_CompareTable} = \@compareTable;
	}
}

sub _generateHeaderTable() {
	my ($self) = @_;
	my @headerTable;
	my @headerFormat;

	my @extractModules = @{$self->{_ExtractModules}};
	my $operationLength = $self->{_OperationLength};
	push @headerFormat, "%${operationLength}s";

	# Headers
	for (my $i = 0; $i <= 1; $i++) {
		my @row;
		push @row, "";
		for (my $j = 0; $j <= $#extractModules; $j++) {
			my $testName = $extractModules[$j]->{_TestName};
			my $index = index($testName, "-");

			# Bodge identification of -rc. Will fail if there is
			# every an -rc10 and will screw up if the name just
			# happened to have -rc at the start
			if (substr($testName, $index, $index+3) =~ /-rc[0-9]/) {
				$index += 4;
			}

			my $element;
			if ($i == 0) {
				my $len = $extractModules[$j]->{_FieldLength};
				if (defined $self->{_CompareTable}) {
					$len += $self->{_CompareLength} + 4;
				}
				$element = substr($testName, 0, $index);
				push @headerFormat, "%${len}s";
			} else {
				$element = substr($testName, $index + 1);
			}
			push @row, $element;
		}
		push @headerTable, [@row];
	}
	$self->{_HeaderTable} = \@headerTable;
	$self->{_HeaderFormat} = \@headerFormat;
}

# Construct final table for printing
sub _generateRenderRatioTable() {
	my ($self) = @_;
	my @finalTable;
	my @formatTable;
	my @compareTable;

	my @titleTable = @{$self->{_TitleTable}};
	my @resultsTable = @{$self->{_ResultsRatioTable}};
	my @stddevTable = @{$self->{_ResultsStdDevTable}} if exists $self->{_ResultsStdDevTable};
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
		if (defined $extractModules[0]->{_RatioMatch}) {
			if ($row[1] !~ $extractModules[0]->{_RatioMatch}) {
				next;
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
			if (defined $self->{_ResultsStdDevTable}) {
				push @row, $stddevTable[$row][$i] // 0;
			} else {
				push @row, [""];
			}
		}
		push @finalTable, [@row];
	}

	if (defined $self->{_StddevMeanTable}) {
		# Stddev mean table
		my @devTable = $self->{_StddevMeanTable};
		my @extractModules = @{$self->{_ExtractModules}};
		my (@dmeanLine, @dminLine, @dmaxLine);
		push @dmeanLine, "Dmean";
		push @dminLine, "Dmin";
		push @dmaxLine, "Dmax";
		push @dmeanLine, $extractModules[0]->{_RatioPreferred};
		push @dminLine, $extractModules[0]->{_RatioPreferred};
		push @dmaxLine, $extractModules[0]->{_RatioPreferred};
		for (my $i = 0; $i <= $#{$devTable[0]}; $i++) {
			push @dmeanLine, ($devTable[0][$i][0], undef, undef);
			push @dminLine, ($devTable[0][$i][1], undef, undef);
			push @dmaxLine, ($devTable[0][$i][2], undef, undef);
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
	my ($self, $rowOrientated) = @_;
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
	if (!$rowOrientated) {
		$maxLength = 0;
		for (my $row = 0; $row <= $#baseline; $row++) {
			my $length = length($baseline[$row][0]);
			if ($length > $maxLength) {
				$maxLength = $length;
			}
		}
		push @formatTable, " %-${maxLength}s";
		$self->{_OperationLength} += $maxLength + 1;
	} else {
		push @formatTable, "";
	}

	# Build column format table
	for (my $i = 0; $i <= $#{$resultsTable[0]}; $i++) {
		my $fieldFormat = "ROW";
		if (!$rowOrientated) {
			$fieldFormat = "%${fieldLength}.${precision}f"
		}
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

sub saveJSONExport() {
	my ($self, $fname) = @_;
	require Cpanel::JSON::XS;
	my $json = Cpanel::JSON::XS->new();
	$json->allow_blessed();
	$json->convert_blessed();
	my $fh;
	open($fh, ">", "$fname.json") or print "Error: could not save $fname.json\n";
	print $fh $json->encode($self);
	close $fh;
}

sub _printComparisonRow() {
	my ($self) = @_;
	my @extractModules = @{$self->{_ExtractModules}};

	$self->_generateRenderTable(1);
	$self->_generateHeaderTable();

	$self->{_PrintHandler}->printHeaderRow($self->{_HeaderTable},
		$self->{_FieldLength},
		$self->{_HeaderFormat});
	$self->{_PrintHandler}->printRow($self->{_RenderTable},
		$self->{_FieldLength},
		$self->{_FieldFormat},
		$extractModules[0]->{_RowFieldFormat});
}

sub printComparison() {
	my ($self, $printRatio) = @_;
	my @extractModules = @{$self->{_ExtractModules}};

	if ($extractModules[0]->{_RowOrientated}) {
		$self->{_PrintHandler}->printTop();
		$self->_printComparisonRow();
		$self->{_PrintHandler}->printBottom();
		return;
	}

	if ($printRatio) {
		$self->_generateRenderRatioTable();
	} else {
		$self->_generateRenderTable(0);
	}
	$self->_generateHeaderTable();

	$self->{_PrintHandler}->printTop();
	$self->{_PrintHandler}->printHeaderRow($self->{_HeaderTable},
		$self->{_FieldLength},
		$self->{_HeaderFormat});
	$self->{_PrintHandler}->printRow($self->{_RenderTable},
		$self->{_FieldLength},
		$self->{_FieldFormat});
	$self->{_PrintHandler}->printBottom();
}

sub printReport() {
	my ($self) = @_;
	print "Unknown data type for reporting raw data\n";
}

1;
