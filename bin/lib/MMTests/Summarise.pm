# Summarise.pm
package MMTests::Summarise;
use MMTests::Cache;
use MMTests::DataTypes;
use MMTests::Extract;
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
	my ($self, $subHeading) = @_;
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

	$self->SUPER::initialise($subHeading);
	$self->{_FieldLength} = 12 if ($self->{_FieldLength} == 0);
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%${fieldLength}d", "%${fieldLength}.2f" ];
	$self->{_FieldHeaders} = [ "Sample", $opName ];
	for (my $header = 0; $header < scalar @{$self->{_SummaryStats}};
	     $header++) {
		push @sumheaders, $self->getStatName($header);
	}
	$self->{_SummaryHeaders} = \@sumheaders;
}

sub getPreferredValue() {
	my ($self, $op) = @_;

	if (!defined($self->{_PreferredVal})) {
		return "Lower";
	}
	return $self->{_PreferredVal};
}

sub summaryOps() {
	my ($self, $subHeading) = @_;

	return $self->getOperations($subHeading);
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
	$sumop =~ s/^_value/$self->{_Opname}/;
	$sumop =~ s/^_mean/$mean/;
	$sumop =~ s/-_mean/-$mean/;

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

	if (!defined($self->{_RatioOperations})) {
		return $self->getOperations($subHeading);
	}
	return $self->filterSubheading($subHeading, $self->{_RatioOperations});
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my %data = %{$self->{_ResultData}};
	my @_operations;
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	if ($subHeading eq "") {
		$subHeading = $self->{_DefaultPlot}
	}
	@_operations = $self->getOperations($subHeading);

	if ($subHeading ne "" && $self->{_ExactSubheading} == 1) {
		if (defined $self->{_ExactPlottype}) {
			$self->{_PlotType} = $self->{_ExactPlottype};
		}
	}

	$self->sortResults();

	my $nr_headings = 0;
	foreach my $heading (@_operations) {
		my @index;
		my @units;
		my @row;
		my $samples;
		my $niceheading = $heading;

		if ($self->{_PlotStripSubheading}) {
			if ($self->{_ClientSubheading} == 1) {
				$niceheading =~ s/-$subHeading$//;
			} else {
				$niceheading =~ s/^$subHeading-//;
			}
		}
		if ($self->{_PlotType} =~ /client-.*/) {
			if ($self->{_ClientSubheading} == 1) {
				$niceheading =~ s/-.*//;
			} else {
				$niceheading =~ s/.*-//;
			}
		}

		@units = map { @{$_->{Values}} } @{$data{$heading}};
		my $iteroff = 0;
		for (my $iter = 0; $iter < scalar(@{$data{$heading}}); $iter++) {
			push @index, map {$iteroff + $_}
				@{$data{$heading}->[$iter]->{SampleNrs}};
			$iteroff = $index[$#index] + 1;
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

				print("$stamp $units[$samples]\n");
			}
		} elsif ($self->{_PlotType} eq "candlesticks") {
			printf "%-${fieldLength}s ", $niceheading;
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "operation-candlesticks") {
			printf "%d %-${fieldLength}s ", $nr_headings, $niceheading;
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "client-candlesticks") {
			printf "%-${fieldLength}s ", $niceheading;
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "single-candlesticks") {
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "client-errorbars") {
			printf "%-${fieldLength}s ", $niceheading;
			$self->_printErrorBarData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "client-errorlines") {
			printf "%-${fieldLength}s ", $niceheading;
			$self->_printErrorBarData($fieldLength, @units);
		} elsif ($self->{_PlotType} =~ "histogram") {
			for ($samples = 0; $samples <= $#units; $samples++) {
				printf("%-${fieldLength}s %${fieldLength}.3f\n",
					$niceheading, $units[$samples]);
			}
		}
	}
}

sub runStatFunc
{
	my ($self, $operation, $func, $dataref, $statsref) = @_;
	my ($mean, $arg);
	my $alpha = 0.05;

	if ($func eq "_value") {
		return $dataref->[0];
	}

	# $dataref is expected to be already sorted in appropriate order
	if ($self->getPreferredValue($operation) eq "Higher") {
		$mean = "hmean";
	} else {
		$mean = "amean";
	}
	$func =~ s/^_mean/$mean/;
	if (defined($$statsref->{$func})) {
		return $$statsref->{$func};
	}

	($func, $arg) = split("-", $func);
	if (!defined $arg) {
		$arg = "";
	} else {
		$arg =~ s/^_mean/$mean/;
	}
	# These are parametrized statistics where parameter is handled by the
	# function itself
	if ($func eq "samples" || $func eq "samplespct" || $func eq "stddev" ||
	    $func eq "coeffvar") {
		$func = "calc_$func";
		no strict "refs";
		return &$func($arg, $dataref, $statsref);
	}
	if ($func eq "meanci" || $func eq "meanci_low" ||
	    $func eq "meanci_high" || $func eq "percentileci_low" ||
	    $func eq "percentileci_high") {
		$func = "calc_$func";
		no strict "refs";
		return &$func($arg, $alpha, $dataref, $statsref);
	}
	# Subselection means are special. They take mean name as an argument
	# and they also need 2-dimensional array with data to know which sample
	# comes from which iteration.
	if ($func eq "submean" || $func eq "submeanci" ||
	    $func eq "submeanci_low" || $func eq "submeanci_high") {
		my @data = map {$_->{Values}} @{$self->{_ResultData}->{$operation}};
		$func = "calc_$func";
		no strict "refs";
		return &$func($mean, $alpha, \@data, $statsref);
	}

	# Percentiles are trivial, no need to copy the whole data array for them
	if ($func eq "percentile") {
		my $nr_elements = scalar(@{$dataref});
		my $count = int ($nr_elements * $arg / 100);

		$count = $count < 1 ? 1 : $count;
		return $dataref->[$count-1];
	}
	$func = "calc_$func";
	if ($arg > 0) {
		# All other numeric arguments are just a percentage of data to
		# compute function from.
		my $nr_elements = scalar(@{$dataref});
		my $count = int ($nr_elements * $arg / 100);
		$count = $count < 1 ? 1 : $count;
		my @data = @{$dataref}[0..($count-1)];

		no strict "refs";
		return &$func(\@data);
	}
	no strict "refs";
	return &$func($dataref, $statsref);
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = $self->summaryOps($subHeading);
	my %data = %{$self->{_ResultData}};

	my %summary;
	my %significance;
	foreach my $operation (@_operations) {
		my @units;
		my $stats = { save_stats => 1 };

		@units = map { @{$_->{Values}} } @{$data{$operation}};
		if ($self->getPreferredValue($operation) eq "Lower") {
			@units = sort { $a <=> $b} @units;
			$stats->{data_ascending} = 1;
		} else {
			@units = sort { $b <=> $a} @units;
			$stats->{data_descending} = 1;
		}

		$summary{$operation} = [];
		foreach my $func (@{$self->{_SummaryStats}}) {
			my $value = $self->runStatFunc($operation, $func,
						       \@units, \$stats);
			if (($value ne "NaN" && $value ne "nan") || $self->{_FilterNaN} != 1) {
				push @{$summary{$operation}}, $value;
			}
		}

		$significance{$operation} = [];

		my $mean = $self->runStatFunc($operation, "_mean", \@units, \$stats);
		push @{$significance{$operation}}, $mean;

		my $stderr = $self->runStatFunc($operation, "stddev-_mean", \@units, \$stats);
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

sub extractSummaryCached() {
	my ($self, $reportDir, $subHeading) = @_;
	shift;
	shift;

	my $cache = MMTests::Cache->new("Summarise_extractSummary", $self->{_ModuleName}, $reportDir, $subHeading);
	if (!defined $cache->{_CUID}) {
		return $self->extractSummary(@_);
	}

	my @fields = (	"_SummaryData",
			"_SignificanceData",
			# "_Operations",
			# "_OperationsSeen",
			# "_GeneratedOperations",
			# "_ResultData",
			# "_ResultDataUnsorted",
			# "_SummaryStats",
			# "_SignificanceLevel"
			);

	if (!$cache->load($self)) {
		$self->extractSummary(@_);
		$cache->save($self, \@fields);
	}
	return 1;
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = $self->ratioSummaryOps($subHeading);
	my %data = %{$self->{_ResultData}};
	my %summary;
	my %summaryCIInterval;
	foreach my $operation (@_operations) {
		my @units;
		my @values;
		my $stats = { save_stats => 1 };

		@units = map { @{$_->{Values}} } @{$data{$operation}};
		if ($self->getPreferredValue($operation) eq "Lower") {
			@units = sort { $a <=> $b} @units;
		} else {
			@units = sort { $b <=> $a} @units;
		}

		foreach my $func (@{$self->{_RatioSummaryStat}}) {
			no strict "refs";
			push @values, $self->runStatFunc($operation, $func,
				\@units, \$stats);
		}

		if (($values[0] ne "NaN" && $values[0] ne "nan") ||
		    $self->{_FilterNaN} != 1) {
			$summary{$operation} = [$values[0]];
			if ($#values == 2 && $values[1] ne "NaN" &&
			    $values[2] ne "NaN") {
				$summaryCIInterval{$operation} =
						[$values[1], $values[2]];
			}
		}
	}
	$self->{_SummaryData} = \%summary;
	$self->{_SummaryCIInterval} = \%summaryCIInterval if %summaryCIInterval;

	return 1;
}

sub extractRatioSummaryCached() {
	my ($self, $reportDir, $subHeading) = @_;
	shift;
	shift;

	my $cache = MMTests::Cache->new("Summarise_extractRatioSummary", $self->{_ModuleName}, $reportDir, $subHeading);
	if (!defined $cache->{_CUID}) {
		return $self->extractRatioSummary(@_);
	}

	my @fields = (	"_SummaryData",
			"_SummaryCIInterval",
			);

	if (!$cache->load($self)) {
		$self->extractRatioSummary(@_);
		$cache->save($self, \@fields);
	}
	return 1;
}


1;
