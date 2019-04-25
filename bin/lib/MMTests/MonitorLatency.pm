# MonitorLatency.pm
#
# Generic module for monitoring latency. It expects input data in format:
# float              float
# <timestamp-in-sec> <latency>
#
# Modules for particular latency type should fill in:
# _{Heading} => prefix of file name with input data (e.g. "read-latency")
# _{DataType} => units in which latency is measured (e.g. DATA_TIME_...)
#
package MMTests::MonitorLatency;
use MMTests::Summarise;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorLatency",
		_FieldLength   => 16,
		_MinLatency    => 20,
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName, $format, $subHeading) = @_;

	if ($subHeading ne "") {
		foreach my $option (split(/,/, $subHeading)) {
			my ($type, $value) = split(/=/, $subHeading);
			if ($type eq "batch") {
				$self->{_Batch} = $value;
			} elsif ($type eq "breakdown") {
				$self->{_MinLatency} = $value;
			}
		}
	}
	if ($subHeading =~ /breakdown/) {
		$self->{_SummaryStats} = [ "samplespct-min,".$self->{_MinLatency},
			"percentile-90", "percentile-93",
			"percentile-95", "percentile-99", "max" ];
	} else {
		my @binSizes;
		my $nr_binsizes = 15;
		my $minBucket = $self->{_Batch} * 10;

		# Build bin sizes
		$binSizes[0] = 1000;
		$binSizes[1] = 2000;
		for (my $i = 2; $i < $nr_binsizes; $i++) {
			$binSizes[$i] = $binSizes[$i-1] + $binSizes[$i-2];
		}
		for (my $i = 0; $i < $nr_binsizes; $i++) {
			$binSizes[$i] += $minBucket;
		}
		$self->{_SummaryStats} = [ "samplespct-min,".$binSizes[0] ];
		for (my $i = 1; $i < $nr_binsizes; $i++) {
			push $self->{_SummaryStats}, "samplespct-".$binSizes[$i-1].",".$binSizes[$i];
		}
	}
	$self->{_RatioSummaryStat} = [ "percentile-95" ];
	$self->SUPER::initialise($reportDir, $testName, $format, $subheading);
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $start_timestamp = 0;
	my $last_timestamp = 0;
	my $cumulative_latency = 0;
	my $count = 0;
	my $file;

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
		if (!defined $self->{_Batch}) {
			$self->addData("latency", $timestamp - $start_timestamp, $latency);
		} else {
			if ($count % $self->{_Batch} == 0) {
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
