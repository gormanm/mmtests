# MonitorLatency.pm
#
# Generic module for monitoring latency. It expects input data in format:
# float              float
# <timestamp-in-sec> <latency>
#
# Modules for particular latency type should fill in:
# _{Heading} => prefix of file name with input data (e.g. "read-latency")
# _{NiceHeading} => heading of data in output (e.g. "Read Latency")
# _{Units} => units in which latency is measured (e.g. s, ms, usec)
#
package MMTests::MonitorLatency;
use MMTests::Monitor;
use MMTests::Stat;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorLatency",
		_DataType      => MMTests::Monitor::MONITOR_LATENCY,
		_MultiopMonitor => 1
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	my $heading = $self->{_NiceHeading};

	print "Time,Time,$heading (".$self->{_Units}.")\n";
}

sub unitMultiplier()
{
	my ($self, $unit) = @_;
	my @units = ("s", "ms", "usec");
	my $mult = 1;

	for (my $i = 0; $i <= $#units; $i++) {
		if ($units[$i] eq $unit) {
			return $mult;
		}
		$mult *= 1000;
	}
	die("Unknown latency unit '$unit'\n");
}

sub extractSummaryBreakdown() {
	my ($self,$subHeading) = @_;
	my @data = @{{$self->dataByOperation()}->["latency"]};
	my @samples;
	my $min_latency;
	my $min_samples = 0;
	my $stalled = 0;
	my $max_stall = 0;

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}d" ];
	$self->{_SummaryHeaders} = [ "Statistic", "Value" ];

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

	push @{$self->{_SummaryData}}, [ "Percentage <$min_latency ", $self->{_Units}, " ", $min_samples * 100 / $#samples ];
	push @{$self->{_SummaryData}}, [ "Seconds Stalled Longer", $stalled / $self->unitMultiplier($self->{_Units}) ];
	push @{$self->{_SummaryData}}, [ "Average bad stall", $stalled / ($#samples - $min_samples) ];
	push @{$self->{_SummaryData}}, [ "Latency 90%", $$quartiles[90] ];
	push @{$self->{_SummaryData}}, [ "Latency 93%", $$quartiles[93] ];
	push @{$self->{_SummaryData}}, [ "Latency 95%", $$quartiles[95] ];
	push @{$self->{_SummaryData}}, [ "Latency 99%", $$quartiles[99] ];
	push @{$self->{_SummaryData}}, [ "Latency Max", calc_max(\@samples) ];
}

sub extractSummaryPercentages() {
	my ($self) = @_;
	my @data = @{{$self->dataByOperation()}->["latency"]};
	my @bins;
	my @binSizes;
	my $nr_binsizes = 15;
	my $nr_values = 0;

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%${fieldLength}d", "%${fieldLength}f" ];
	$self->{_SummaryHeaders} = [ "Latency", "Percentage" ];

	# Build bin sizes
	$binSizes[0] = 1000;
	$binSizes[1] = 2000;
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

		for ($i = 0; $i < $nr_binsizes; $i++) {
			if ($row[1] < $binSizes[$i]) {
				last;
			}
		}
		$bins[$i]++;
		$nr_values++;
	}

	my $percentage = 0;
	for (my $i = 0; $i < $nr_binsizes; $i++) {
		if (!$nr_values) {
			$percentage = 100;
		} else {
			$percentage += $bins[$i] * 100 / $nr_values;
		}
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
	my $file;

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
	$self->{_FieldHeaders} = [ "Op", "Time", "Latency" ];
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}f", "%${fieldLength}f" ];

	$file = "$reportDir/".$self->{_Heading}."-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} elsif (-e "$file.gz") {
		open(INPUT, "gunzip -c $file.gz|") || die("Failed to open $file.gz: $!\n");
	} else {
		return;
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
			$self->addData("latency", $timestamp - $start_timestamp, $latency);
		} else {
			if ($count % $batch == 0) {
				$self->addData("latency",
					  $last_timestamp - $start_timestamp,
					  $cumulative_latency);
				$cumulative_latency = 0;
				$last_timestamp = $timestamp;
				$count = 0;
			}
			$cumulative_latency += $latency;
		}
	}
}

1;
