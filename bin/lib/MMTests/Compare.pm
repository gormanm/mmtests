# Compare.pm
#
# This is base class description for modules that take summaries from
# the Extract classes and compare them with each other.

package MMTests::Compare;
use MMTests::DataTypes;
use MMTests::Stat;
use MMTests::Blessless qw(blessless);
use MMTests::PrintGeneric;
use MMTests::PrintHtml;
use MMTests::PrintDocbook;
use strict;
use POSIX;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName 	=> "Compare",
		_FieldLength	=> 0,
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

	$self->{_ExtractModules} = $extractModulesRef;
	my @extractModules = @{$extractModulesRef};
	$self->{_FieldLength} = $extractModules[0]->{_FieldLength};
	$self->{_Precision} = $extractModules[0]->{_Precision};
	if ($self->{_ModuleName} eq "" || $self->{_ModuleName} eq "Compare") {
		$self->{_ModuleName} = $extractModules[0]->{_ModuleName};
		$self->{_ModuleName} =~ s/^Extract/Compare/;
	}
}

sub setFormat() {
	my ($self, $format) = @_;

	if ($format eq "html") {
		$self->{_PrintHandler} = MMTests::PrintHtml->new(1);
	} elsif ($format eq "docbook") {
		$self->{_PrintHandler} = MMTests::PrintDocbook->new(1);
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

sub _generateComparisonTable() {
	my ($self, $showCompare) = @_;
	my %resultsTable;
	my %compareTable;
	my %significanceTable;

	my @extractModules = @{$self->{_ExtractModules}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my %baseline = %{$baselineRef};
	my $baseSignificanceRef = $extractModules[0]->{_SignificanceData};
	my %baseSignificance = %{$baseSignificanceRef // {}};
	my $columns = scalar(@{$extractModules[0]->{_SummaryStats}});

	for my $operation (keys %baseline) {
		$resultsTable{$operation} = [];
		$compareTable{$operation} = [];

		for (my $column = 0; $column < $columns; $column++) {
			my @data;
			my @compare;
			my $compareOp;

			$compareOp = $extractModules[0]->getStatCompareFunc(
				$operation,
				$extractModules[0]->{_SummaryStats}->[$column]);

			for (my $module = 0; $module <= $#extractModules; $module++) {
				no strict "refs";
				my $summaryRef = $extractModules[$module]->{_SummaryData};
				my %summary = %{$summaryRef};

				if ($summary{$operation}[$column] eq "") {
					$summary{$operation}[$column] = "NaN";
				}
				if (exists $summary{$operation} && $summary{$operation}[$column] != -1 && $summary{$operation}[$column] ne "NaN" && $baseline{$operation}[$column] != -1) {
					push @data,
					     $summary{$operation}[$column];
					push @compare,
					     &$compareOp($summary{$operation}[$column], $baseline{$operation}[$column]);
				} else {
					push @data, 0;
					push @compare, 0;
				}
			}
			push @{$resultsTable{$operation}}, [@data];
			push @{$compareTable{$operation}}, [@compare];
		}
	}

	my %significance;
	for my $operation (keys %baseline) {
		$significance{$operation} = [];
		my %baselineSignificance;
		for (my $module = 0; $module <= $#extractModules; $module++) {
			my $significanceRef = $extractModules[$module]->{_SignificanceData};
			if ($significanceRef) {
				my %rdata = %{$significanceRef};

				if ($module == 0) {
					%baselineSignificance = %{$significanceRef};
					push @{$significance{$operation}}, 0;
					push @{$significance{$operation}}, 0;
				} else {
						my $baselineRRef = \@{$baselineSignificance{$operation}};
						my $rowRef = \@{$rdata{$operation}};
						my ($val, $prob) = $self->_significanceTest($baselineRRef, $rowRef);
						push @{$significance{$operation}}, $val;
						push @{$significance{$operation}}, $prob;
				}
			} else {
				push @{$significance{$operation}}, 0;
				push @{$significance{$operation}}, 0;
			}
		}
	}

	$self->{_ResultsTable} = \%resultsTable;
	if ($showCompare) {
		$self->{_CompareTable} = \%compareTable;
		$self->{_ResultsSignificanceTable} = \%significance;
	}
}

sub _generateRatioComparisonTable() {
	my ($self, $showCompare) = @_;
	my %compareRatioTable;
	my %compareTable;
	my %normCompareTable;

	my @extractModules = @{$self->{_ExtractModules}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my %baseline = %{$baselineRef};
	my $baseCILenRef = $extractModules[0]->{_SummaryCILen};
	my %baseCILen = %{$baseCILenRef // {}};
	my $preferred = $extractModules[0]->getRatioPreferredValue();

	for my $operation (keys %baseline) {
		my ($ratioCompareOp, $compareOp);

		$compareRatioTable{$operation} = [];
		$compareTable{$operation} = [];
		$normCompareTable{$operation} = [];

		$ratioCompareOp = "sdiff";
		if (defined $extractModules[0]->{_RatioCompareOp}) {
			$ratioCompareOp = $extractModules[0]->{_RatioCompareOp};
		}
		$compareOp = "pdiff";
		if ($preferred eq "Lower") {
			$compareOp = "pndiff";
		}

		for (my $module = 0; $module <= $#extractModules; $module++) {
			no strict "refs";
			my $summaryRef = $extractModules[$module]->{_SummaryData};
			my %summary = %{$summaryRef};
			my $summaryCILenRef = $extractModules[$module]->{_SummaryCILen};
			my %summaryCILen = %{$summaryCILenRef};
			my ($ratio, $ratiocmp, $normcmp);
			my ($aval, $aci, $bval, $bci);

			if ($summary{$operation}[0] eq "") {
				$summary{$operation}[0] = "NaN";
			}
			$aval = $summary{$operation}[0];
			$aci = $summaryCILen{$operation};
			$bval = $baseline{$operation}[0];
			$bci = $baseCILen{$operation};
			if ($aval != -1 && $aval ne "NaN" && $bval != -1 && $bval ne "NaN") {
				# If preferred value for current operation is
				# different from preferred value for the whole
				# comparison, swap values to make ratios
				# comparable.
				if ($extractModules[$module]->getPreferredValue($operation) ne $preferred) {
					($aval, $bval) = ($bval, $aval);
					($aci, $bci) = ($bci, $aci);
				}
				$ratio = rdiff($aval, $bval);
				$ratiocmp = &$compareOp($ratio, 1);
				if ($baseCILenRef) {
					$normcmp = &$ratioCompareOp($aval, $aci, $bval, $bci);
					if ($normcmp eq "NaN" || $normcmp eq "nan") {
						$normcmp = 0;
					}
				}
			} else {
				$ratio = 1;
				$ratiocmp = 0;
				$normcmp = 0;
			}
			push @{$compareRatioTable{$operation}}, $ratio;
			push @{$compareTable{$operation}}, $ratiocmp;
			push @{$normCompareTable{$operation}}, $normcmp;
		}
	}

	my @geomean;
	my @normcmpmean;
	my $cmpRatio;
	for (my $module = 0; $module <= $#extractModules; $module++) {
		my @units;
		for my $operation (keys %baseline) {
			push @units, $normCompareTable{$operation}[$module];
		}
		push @normcmpmean, [ calc_amean(\@units), calc_min(\@units), calc_max(\@units) ];

		@units = ();
		for my $operation (keys %baseline) {
			$cmpRatio = $compareRatioTable{$operation}[$module];
			if ($cmpRatio eq "NaN" || $cmpRatio eq "") {
				push @units, 1;
			} elsif ($cmpRatio != 0) {
				push @units, $cmpRatio;
			} else {
				push @units, 0.00001;
			}
		}
		push @geomean, calc_geomean(\@units);
	}

	$self->{_ResultsNormalizedTable} = \%normCompareTable if $baseCILenRef;
	$self->{_NormalizedDiffStatsTable} = \@normcmpmean if $baseCILenRef;
	$self->{_ResultsRatioTable} = \%compareRatioTable;
	$self->{_GeometricMeanTable} = \@geomean;
	if ($showCompare) {
		$self->{_CompareTable} = \%compareTable;
	}
}

sub _generateHeaderTable() {
	my ($self, $printSignificance) = @_;
	my @headerTable;
	my @headerFormat;

	my @extractModules = @{$self->{_ExtractModules}};
	my $operationLength = $self->{_OperationLength};
	push @headerFormat, "%${operationLength}s";

	if (! defined $self->{_CompareLength}) {
		$self->{_CompareLength} = 7;
	}

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
	my ($self, $subHeading) = @_;
	my @finalTable;
	my @formatTable;
	my @compareTable;

	my %resultsTable = %{$self->{_ResultsRatioTable}};
	my %normResultsTable = %{$self->{_ResultsNormalizedTable}} if exists $self->{_ResultsNormalizedTable};
	my $fieldLength = $self->{_FieldLength};
	my $compareLength = 0;
	my $precision = 2;
	if ($self->{_Precision}) {
		$precision = $self->{_Precision};
	}
	my %compareTable;
	if (defined $self->{_CompareTable}) {
		%compareTable = %{$self->{_CompareTable}};
		$compareLength = $self->{_CompareLength};
	}

	my @extractModules = @{$self->{_ExtractModules}};
	my @operations = $extractModules[0]->ratioSummaryOps($subHeading);

	# Format string for source table rows
	my $maxLength = 0;
	for my $operation (@operations) {
		my $length = length($operation);
		if ($length > $maxLength) {
			$maxLength = $length;
		}
	}
	# Account for 'Ratio ' prefix
	$maxLength += 6;
	push @formatTable, "%-${maxLength}s";
	$self->{_OperationLength} = $maxLength;

	# Build column format table
	for (my $i = 0; $i <= scalar @operations; $i++) {
		my $fieldFormat = "%${fieldLength}.${precision}f";
		if (defined $self->{_CompareTable}) {
			push @formatTable, ($fieldFormat, " (%${compareLength}.2f%%)", " (\%+${compareLength}.2fs)");
		} else {
			push @formatTable, ($fieldFormat, "");
		}
	}

	my $maxCols = 0;

	# Final comparison table
	my @extractModules = @{$self->{_ExtractModules}};
	my @rowLine;
	my $preferred = $extractModules[0]->getRatioPreferredValue();
	for my $operation (@operations) {
		@rowLine = ("Ratio $operation");
		if ($#{$resultsTable{$operation}} > $maxCols) {
			$maxCols = $#{$resultsTable{$operation}};
		}
		next if $#{$resultsTable{$operation}} < $maxCols;
		for (my $i = 0; $i < scalar(@{$resultsTable{$operation}}); $i++) {
			push @rowLine, $resultsTable{$operation}[$i];
			if (defined $self->{_CompareTable}) {
				push @rowLine, $compareTable{$operation}[$i];
			} else {
				push @rowLine, "NaN";
			}
			if (defined $self->{_ResultsNormalizedTable}) {
				push @rowLine, $normResultsTable{$operation}[$i] // 0;
			} else {
				push @rowLine, "NaN";
			}
		}
		push @finalTable, [@rowLine];
	}

	if (defined $self->{_NormalizedDiffStatsTable}) {
		# Stddev mean table
		my @ndiffTable = $self->{_NormalizedDiffStatsTable};
		my @extractModules = @{$self->{_ExtractModules}};
		my (@dmeanLine, @dminLine, @dmaxLine);
		push @dmeanLine, "Dmean $preferred";
		push @dminLine, "Dmin  $preferred";
		push @dmaxLine, "Dmax  $preferred";
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
	push @rowLine, "Gmean $preferred";
	for (my $i = 0; $i <= $#{$geomeanTable[0]}; $i++) {
		push @rowLine, ($geomeanTable[0][$i], undef, undef);
	}
	push @finalTable, [@rowLine];

	$self->{_RenderTable} = \@finalTable;
	$self->{_FieldFormat} = \@formatTable;
}

# Construct final table for printing
sub _generateRenderTable() {
	my ($self, $printSignificance, $subHeading) = @_;
	my @finalTable;
	my @formatTable;
	my @compareTable;

	my @extractModules = @{$self->{_ExtractModules}};
	my @operations = $extractModules[0]->summaryOps($subHeading);
	my $fieldLength = $self->{_FieldLength};
	my $compareLength = 0;
	my $precision = 2;
	if ($self->{_Precision}) {
		$precision = $self->{_Precision};
	}
	my %compareTable;
	if (defined $self->{_CompareTable}) {
		%compareTable = %{$self->{_CompareTable}};
		$compareLength = $self->{_CompareLength};
		if (! defined $compareLength) {
			$compareLength = 7;
		}
	}

	# Format string for columns
	my $maxLength = 0;
	for my $operation (@operations) {
		for my $header (@{$extractModules[0]->{_SummaryStats}}) {
			my $len = length($extractModules[0]->getStatName(
							$operation, $header));
			if ($len > $maxLength) {
				$maxLength = $len;
			}
		}
	}
	push @formatTable, "%-${maxLength}s";
	$self->{_OperationLength} = $maxLength;

	# Format string for source table rows
	$maxLength = 0;
	for my $operation (@operations) {
		my $length = length($operation);
		if ($length > $maxLength) {
			$maxLength = $length;
		}
	}
	push @formatTable, " %-${maxLength}s";
	$self->{_OperationLength} += $maxLength + 1;

	# Build column format table
	my %resultsTable = %{$self->{_ResultsTable}};
	for (my $i = 0; $i <= scalar(@{$resultsTable{$operations[0]}}) + 1; $i++) {
		my $fieldFormat = "%${fieldLength}.${precision}f";
		if (defined $self->{_CompareTable}) {
			push @formatTable, ($fieldFormat, " (%${compareLength}.2f%%)");
		} else {
			push @formatTable, ($fieldFormat, "");
		}
	}

	my %significanceTable;
	if (defined $self->{_ResultsSignificanceTable}) {
		%significanceTable = %{$self->{_ResultsSignificanceTable}};
	}

	# Final comparison table
	my @extractModules = @{$self->{_ExtractModules}};
	my @rowLine;
	for (my $header = 0;
	     $header < scalar(@{$extractModules[0]->{_SummaryStats}});
	     $header++) {
		for my $operation (@operations) {
			my $headerName = $extractModules[0]->getStatName(
				$operation,
				$extractModules[0]->{_SummaryStats}->[$header]);
			@rowLine = ($headerName, $operation);
			for (my $i = 0; $i < scalar(@{$resultsTable{$operation}[$header]}); $i++) {
				push @rowLine, $resultsTable{$operation}[$header][$i];
				if (defined $self->{_CompareTable}) {
					my $sig = "";
					# Determine if this is a good row to mark significance
					if ($headerName =~ /^.mean/) {
						if ($significanceTable{$operation}[$i*2]) {
							$sig = ":SIG:";
						} else {
							$sig = ":NSIG:";
						}
					}
					push @rowLine, "$compareTable{$operation}[$header][$i]$sig";
				} else {
					push @rowLine, [""];
				}
			}
			push @finalTable, [@rowLine];
		}
	}

	if ($printSignificance && defined $self->{_ResultsSignificanceTable}) {
		my @rowLine;
		for my $operation (@operations) {
			@rowLine = ("Significant", $operation);
			for (my $i = 0; $i <= scalar(@{$significanceTable{$operation}}); $i++) {
				push @rowLine, $significanceTable{$operation}[$i];
			}
			push @finalTable, [@rowLine];
		}
	}

	$self->{_RenderTable} = \@finalTable;
	$self->{_FieldFormat} = \@formatTable;
}

sub extractComparison() {
	my ($self, $printRatio, $showCompare) = @_;

	if ($printRatio) {
		$self->_generateRatioComparisonTable($showCompare);
	} else {
		$self->_generateComparisonTable($showCompare);
	}
}

sub saveJSONExport() {
	my ($self, $fname) = @_;
	require Cpanel::JSON::XS;
	my $json = Cpanel::JSON::XS->new();
	$json->allow_blessed();
	$json->convert_blessed();
	my $fh;
	open($fh, ">", "$fname") or print "Error: could not save $fname\n";
	print $fh $json->encode($self);
	close $fh;
}

sub printComparison() {
	my ($self, $printRatio, $printSignificance, $subHeading) = @_;
	my @extractModules = @{$self->{_ExtractModules}};

	if ($printRatio) {
		$self->_generateRenderRatioTable($subHeading);
	} else {
		$self->_generateRenderTable($printSignificance, $subHeading);
	}
	$self->_generateHeaderTable($printSignificance);

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

# Two sample t-test
sub _significanceTest() {
	my ($self, $baselineref, $rdataref) = @_;

	my @baseline = @$baselineref;
	my @rdata = @$rdataref;

	my $variance_base = $baseline[1];
	my $variance_rdata = $rdata[1];
	my $num_samples_base = $baseline[2];
	my $num_samples_rdata = $rdata[2];

	my $stderror = 0;
	if ($num_samples_base && $num_samples_rdata) {
		$stderror = sqrt(($variance_base**2/$num_samples_base) + ($variance_rdata**2/$num_samples_rdata));
	}

	# Special case the situation where the variance of both data sets
	# is zero, which means we can't perform a t-test.

	if (!$stderror) {
		my $delta = $baseline[0] - $rdata[0];
		my $sig = $delta ? 1 : 0;

		# If there is a difference in means then there's 0%
		# probability of $delta being described by our model
		# (with zero variance, our model has a single value for
		# the mean). No difference is 100% described by the model.

		my $prob = $delta ? 0 : 100;

		return ($sig, $prob);
	}

	my $t_stat = abs(($baseline[0] - $rdata[0]) / $stderror);

	# Each sample variance as N-1 degrees of freedom.
	my $df = $num_samples_base + $num_samples_rdata - 2;

	my $t_prob = qx(echo 'pt(c($t_stat), $df, lower.tail = FALSE)' | R --slave);
	$t_prob =~ s/\[1\]|\s//g;

	my $p_value = $t_prob*2;

	my $significance_level = $baseline[3];

	return ($p_value < $significance_level, $p_value*100);
}

1;
