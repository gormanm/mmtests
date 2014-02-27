# MonitorReadlatency.pm
package MMTests::MonitorReadlatency;
use MMTests::Monitor;
use VMR::Report;
use VMR::Stat;
our @ISA = qw(MMTests::Monitor); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorReadlatency",
		_DataType      => MMTests::Monitor::MONITOR_READLATENCY,
		_ResultData    => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	my $headingIndex = $self->{_HeadingIndex};

	print "Time,Time,Read Latency (ms)\n";
}

sub extractSummaryBreakdown() {
	my ($self,$subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my @samples;
	my $min_latency;
	my $min_samples = 0;
	my $stalled = 0;
	my $max_stall = 0;

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}d" ];
	$self->{_SummaryHeaders} = [ "Heading", "" ];

	foreach my $option (split(/,/, $subHeading)) {
		my ($type, $value) = split(/=/, $subHeading);
		if ($subHeading eq "breakdown" || $type eq "breakdown") {
			$min_latency = $value;
		}
	}
	if ($min_latency == 0) {
		$min_latency = 20;
	}

	foreach my $rowRef (@data) {
		my @row = @{$rowRef};

		# Ouch on memory usage but hey.
		push @samples, $row[1];

		if ($row[1] < $min_latency) {
			$min_samples++;
		} else {
			$stalled += $row[1];
		}
	}

	my $quartiles = calc_quartiles(@samples);

	push @{$self->{_SummaryData}}, [ "Percentage <$min_latency ms", $min_samples * 100 / $#samples ];
	push @{$self->{_SummaryData}}, [ "Seconds Stalled Longer", $stalled / 1000 ];
	push @{$self->{_SummaryData}}, [ "Average bad stall", $stalled / ($#samples - $min_samples) ];
	push @{$self->{_SummaryData}}, [ "Latency 90%", $$quartiles[90] ];
	push @{$self->{_SummaryData}}, [ "Latency 93%", $$quartiles[93] ];
	push @{$self->{_SummaryData}}, [ "Latency 95%", $$quartiles[95] ];
	push @{$self->{_SummaryData}}, [ "Latency 99%", $$quartiles[99] ];
	push @{$self->{_SummaryData}}, [ "Latency Max", calc_max(@samples) ];
}

sub extractSummaryPercentages() {
	my ($self) = @_;
	my @data = @{$self->{_ResultData}};
	my @bins;
	my @binSizes;
	my $nr_binsizes = 15;
	my $nr_values = 0;

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%${fieldLength}d", "%${fieldLength}f" ];
	$self->{_SummaryHeaders} = [ "Latency", "Percentage" ];

	# Build bin sizes
	$binSizes[0] = 10;
	$binSizes[1] = 20;
	for (my $i = 2; $i < $nr_binsizes; $i++) {
		$binSizes[$i] = $binSizes[$i-1] + $binSizes[$i-2];
	}
	for (my $i = 0; $i < $nr_binsizes; $i++) {
		$binSizes[$i] += $self->{_MinBucket};
	}

	foreach my $rowRef (@data) {
		my @row = @{$rowRef};
		my $i;
		my $lastBinsize = 0;

		for ($i = 1; $i < $nr_binsizes; $i++) {
			if ($row[1] < $binSizes[$i-1] && $row[1] <  $binSizes[$i]) {
				last;
			}
		}
		$i = $i - 1;
		$bins[$i]++;
		$nr_values++;
	}

	my $percentage = 0;
	for (my $i = 0; $i < $nr_binsizes; $i++) {
		$percentage += $bins[$i] * 100 / $nr_values;
		push @{$self->{_SummaryData}}, [ $binSizes[$i], $percentage ];
	}
	return 1;
}

sub extractSummary() {
	my ($self, $subHeading) = @_;

	if ($subHeading =~ /breakdown/) {
		return $self->extractSummaryBreakdown($subHeading);
	}

	return $self->extractSummaryPercentages($subHeading);
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $start_timestamp = 0;
	my $last_timestamp = 0;
	my $cumulative_latency = 0;
	my $batch = 0;
	my $count = 0;

	if ($subHeading ne "") {
		foreach my $option (split(/,/, $subHeading)) {
			my ($type, $value) = split(/=/, $subHeading);
			if ($type eq "batch") {
				$batch = $value;
				$self->{_MinBucket} = $value * 10;
			}
		}
	}

	# TODO: Auto-discover lengths and handle multi-column reports
	my $fieldLength = 16;
	$self->{_FieldLength} = $self->{_SummaryLength} = $fieldLength;
	$self->{_FieldHeaders} = [ "Time", "Latency" ];
	$self->{_FieldFormat} = [ "%${fieldLength}f", "%${fieldLength}f" ];

	my $file;
	foreach my $test_file ("$reportDir/read-latency-$testName-$testBenchmark",
			"$reportDir/read-latency-$testName-$testBenchmark.gz",
			"$reportDir/write-latency-$testName-$testBenchmark",
			"$reportDir/write-latency-$testName-$testBenchmark.gz",
			"$reportDir/inbox-open-$testName-$testBenchmark",
			"$reportDir/inbox-open-$testName-$testBenchmark.gz",
			"$reportDir/mmap-access-latency-$testName-$testBenchmark") {
		if (-e $test_file) {
			$file = $test_file;
			last;
		}
	}

	if ($file !~ /^.gz/) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		open(INPUT, "gunzip -c $file.gz|") || die("Failed to open $file.gz: $!\n");
	}

	while (<INPUT>) {
		my ($timestamp, $latency) = split(/\s/, $_);
		if ($start_timestamp == 0) {
			$start_timestamp = $timestamp;
			$last_timestamp = $timestamp;
			$cumulative_latency = 0;
		}

		$count++;
		if ($batch == 0) {
			push @{$self->{_ResultData}},
				[ $timestamp - $start_timestamp, $latency ];
		} else {
			if ($count % $batch == 0) {
				push @{$self->{_ResultData}},
					[ $last_timestamp - $start_timestamp,
					  $cumulative_latency];
				$cumulative_latency = 0;
				$last_timestamp = $timestamp;
				$count = 0;
			}
			$cumulative_latency += $latency;
		}
	}
}

1;
