# Extract.pm
#
# This is base class description for modules that parse MM Tests directories
# and extract information from them

package MMTests::Extract;

use constant DATA_NONE			=> 0;
use constant DATA_CPUTIME		=> 1;
use constant DATA_WALLTIME		=> 2;
use constant DATA_WALLTIME_VARIABLE	=> 3;
use constant DATA_WALLTIME_OUTLIERS	=> 4;
use constant DATA_OPSSEC		=> 5;
use constant DATA_THROUGHPUT		=> 6;
use VMR::Stat;
use MMTests::PrintGeneric;
use MMTests::PrintHtml;
use List::Util ();
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName 	=> "Extract",
		_DataType	=> 0,
		_FieldHeaders	=> [],
		_FieldLength	=> 0,
		_Headers	=> [ "Base" ],
	};
	bless $self, $class;
	return $self;
}

sub getModuleName() {
	my ($self) = @_;
	return $self->{_ModuleName};
}

sub initialise() {
	my ($self, $reportDir, $testName, $format) = @_;
	my (@fieldHeaders, @plotHeaders, @summaryHeaders);
	my ($fieldLength, $plotLength, $summaryLength);

	if ($self->{_DataType} == DATA_WALLTIME) {
		$fieldLength = 12;
		$summaryLength = 12;
		$plotLength = 12;
		@fieldHeaders = ("Unit", "WallTime");
		@summaryHeaders = ("Time", "Unit");
		@plotHeaders = ("Unit", "WallTime");
	} elsif ($self->{_DataType} == DATA_THROUGHPUT) {
		$fieldLength = 12;
		$plotLength = 12;
		$summaryLength = 12;
		@fieldHeaders = ("Unit", "Throughput");
		@plotHeaders = ("Unit", "Throughput");
		@summaryHeaders = ("Min", "Mean", "TrimMean", "Stddev", "Max");
	} else {
		$fieldLength = 18;
		@fieldHeaders = ("UnknownType");
	}

	$self->{_TestName} = $testName;
	$self->{_FieldLength}  = $fieldLength;
	$self->{_FieldHeaders} = \@fieldHeaders;
	$self->{_PlotLength} = $plotLength;
	$self->{_PlotHeaders} = \@plotHeaders;
	$self->{_SummaryLength}  = $summaryLength;
	$self->{_SummaryHeaders} = \@summaryHeaders;
}

sub setFormat() {
	my ($self, $format) = @_;
	if ($format eq "html") {
		$self->{_PrintHandler} = MMTests::PrintHtml->new();
	} else {
		$self->{_PrintHandler} = MMTests::PrintGeneric->new();
	}
}

sub printDataType() {
	my ($self) = @_;
	if ($self->{_DataType} == DATA_WALLTIME) {
		print "WallTime";
	} elsif ($self->{_DataType} == DATA_THROUGHPUT) {
		print "Throughput";
	} else {
		print "Unknown";
	}
}

sub printExtraHeaders() {
	my ($self) = @_;
	if (!defined $self->{_ExtraLength}) {
		return;
	}
	$self->{_PrintHandler}->printHeaders(
		$self->{_ExtraLength}, $self->{_ExtraHeaders},
		$self->{_FieldHeaderFormat});
}

sub printReportTop() {
	my ($self) = @_;
	$self->{_PrintHandler}->printTop();
}

sub printReportBottom() {
	my ($self) = @_;
	$self->{_PrintHandler}->printBottom();
}

sub printFieldHeaders() {
	my ($self) = @_;
	$self->{_PrintHandler}->printHeaders(
		$self->{_FieldLength}, $self->{_FieldHeaders},
		$self->{_FieldHeaderFormat});
}

sub printPlotHeaders() {
	my ($self) = @_;
	$self->{_PrintHandler}->printHeaders(
		$self->{_PlotLength}, $self->{_PlotHeaders},
		$self->{_FieldHeaderFormat});
}

sub setSummaryLength() {
	my ($self, $subHeading);

	$self->{_SummaryLength} = $self->{_FieldLength};
}

sub printSummaryHeaders() {
	my ($self) = @_;
	if (defined $self->{_SummaryLength}) {
		$self->{_PrintHandler}->printHeaders(
			$self->{_SummaryLength}, $self->{_SummaryHeaders},
			$self->{_FieldHeaderFormat});
	} else {
		$self->printFieldHeaders();
	}
}


sub _printSimplePlotData() {
	my ($self, $fieldLength, @data) = @_;

	my $mean = calc_mean(@data);

	printf("%${fieldLength}.3f\n", $mean);
}

sub _printCandlePlotData() {
	my ($self, $fieldLength, @data) = @_;

	my $stddev = calc_stddev(@data);
	my $mean = calc_mean(@data);
	my $min  = calc_min(@data);
	my $max  = calc_max(@data);
	my $low_stddev = calc_max( ($mean - $stddev, $min) );
	my $high_stddev = calc_min( ($mean + $stddev, $max) );

	printf("%${fieldLength}.3f %${fieldLength}.3f %${fieldLength}.3f %${fieldLength}.3f %${fieldLength}.3f	# stddev=%-${fieldLength}.3f\n", $low_stddev, $min, $max, $high_stddev, $mean, $stddev);
}

sub _printCandlePlot() {
	my ($self, $fieldLength, $column) = @_;
	my @data;

	# Extract the data
	foreach my $row (@{$self->{_ResultData}}) {
		my @rowArray = @{$row};
		push @data, $rowArray[$column];
	}

	$self->_printCandlePlotData($fieldLength, @data);
}

sub _time_to_elapsed {
	my ($self, $line) = @_;
	my ($user, $system, $elapsed, $cpu) = split(/\s/, $line);
	my @elements = split(/:/, $elapsed);
	my ($hours, $minutes, $seconds);
	if ($#elements == 1) {
		$hours = 0;
		($minutes, $seconds) = @elements;
	} else {
		($hours, $minutes, $seconds) = @elements;
	}
	$elapsed = $hours * 60 * 60 + $minutes * 60 + $seconds;

	return $elapsed;
}

sub printPlot() {
	my ($self, $subheading) = @_;
	my $fieldLength = $self->{_PlotLength};

	if ($self->{_DataType} == DATA_WALLTIME) {
		$self->printSummary();
	} elsif ($self->{_DataType} == DATA_THROUGHPUT) {
		my $column = 0;
		$column = $self->{_SummariseColumn} if defined $self->{_SummariseColumn};
		$self->_printCandlePlot($fieldLength, $column);
	} else {
		print "Unhandled data type for plotting.\n";
	}
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @formatList;
	my $fieldLength = $self->{_FieldLength};
	if (defined $self->{_FieldFormat}) {
		@formatList = @{$self->{_FieldFormat}};
	}

	if ($self->{_DataType} == DATA_WALLTIME) {
		my (%units, @walltimes);
		@walltimes = [];
		foreach my $row (@{$self->{_ResultData}}) {
			my @rowArray = @{$row};
			$units{$rowArray[0]} = 1;
			push @{$walltimes[$rowArray[0]]}, $rowArray[1];
		}

		foreach my $unit (sort {$a <=> $b} (keys %units)) {
			my $mean;
			if ($self->{_UseTrueMean} == 1) {
				$mean = calc_true_mean(99, 1, @{$walltimes[$unit]});
			} else {
				$mean = calc_mean(@{$walltimes[$unit]});
			}
			push @{$self->{_SummaryData}}, [$unit, $mean];
		}
	} else {
		print "Unknown data type for summarising\n";
	}

	return 1;
}

sub extractSummaryR() {
	my ($self, $subHeading, $RstatsFile) = @_;
	my @formatList;
	my $fieldLength = $self->{_FieldLength};
	if (defined $self->{_FieldFormat}) {
		@formatList = @{$self->{_FieldFormat}};
	}

	open(INPUT, $RstatsFile) || die("Failed to open $RstatsFile\n");

	my @row;
	my @rowNames;
	
	# TODO: This might depend on the data type?
	push @row, "";
	push @rowNames, "Unit";

	# find the position of our test in the table header
	my $testName = $self->{_TestName};
	my $header = readline INPUT;
	chomp $header;

	my @tests = split(/;/, $header);
	my $testIndex = List::Util::first { $tests[$_] eq $testName } 0..$#tests;
	die ("Test $testName not found in $RstatsFile\n") unless defined $testIndex;

	# the following rows with values have an extra column in the beginning
	$testIndex++;

	while (<INPUT>) {
		my $line = $_;
		chomp $line;
		my @values = split(/;/, $line);
		push @rowNames, $values[0];
		push @row, $values[$testIndex];
	}
	close INPUT;

	push @{$self->{_SummaryData}}, \@row;
	$self->{_SummaryHeaders} = \@rowNames;
}

sub printSummary() {
	my ($self, $subHeading) = @_;
	my @formatList;
	my $fieldLength = $self->{_FieldLength};
	if (defined $self->{_FieldFormat}) {
		@formatList = @{$self->{_FieldFormat}};
	}

	$self->extractSummary($subHeading);
	$self->{_PrintHandler}->printRow($self->{_SummaryData}, $fieldLength, $self->{_FieldFormat});
}

sub _printClientReport() {
	my ($self, $reportDir, @clients) = @_;
	my @data = @{$self->{_ResultData}};

	my $fieldLength = $self->{_FieldLength};
	foreach my $client (@clients) {
		$self->{_PrintHandler}->printRow($data[$client], $fieldLength, $self->{_FieldFormat}, "%-${fieldLength}d", $client);
	}
}

sub _printClientExtra() {
	my ($self, $reportDir, @clients) = @_;
	my @data = @{$self->{_ExtraData}};

	my $fieldLength = $self->{_ExtraLength};
	foreach my $client (@clients) {
		$self->{_PrintHandler}->printRow($data[$client], $fieldLength, $self->{_ExtraFormat}, "%-${fieldLength}d", $client);
	}
}

sub printExtra() {
	my ($self) = @_;
	my @formatList;
	if (!defined $self->{_ExtraData}) {
		return;
	}

	$self->{_PrintHandler}->printRow($self->{_ExtraData}, $self->{_ExtraLength}, $self->{_ExtraFormat});
}

sub printReport() {
	my ($self) = @_;
	if ($self->{_DataType} == DATA_WALLTIME ||
			$self->{_DataType} == DATA_THROUGHPUT) {
		$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
	} else {
		print "Unknown data type for reporting extracted raw data\n";
	}
}

1;
