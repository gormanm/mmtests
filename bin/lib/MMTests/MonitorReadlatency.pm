# MonitorReadlatency.pm
package MMTests::MonitorReadlatency;
use MMTests::Monitor;
use VMR::Report;
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

sub extractSummary() {
	my ($self) = @_;
	my @data = @{$self->{_ResultData}};
	my @bins;
	my @binSizes;
	my $nr_binsizes = 15;
	my $nr_values = 0;

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%${fieldLength}d", "%${fieldLength}f" ];

	# Build bin sizes
	$binSizes[0] = 10;
	$binSizes[1] = 20;
	for (my $i = 2; $i < $nr_binsizes; $i++) {
		$binSizes[$i] = $binSizes[$i-1] + $binSizes[$i-2];
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

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $start_timestamp = 0;

	# TODO: Auto-discover lengths and handle multi-column reports
	my $fieldLength = 16;
	$self->{_FieldLength} = $self->{_SummaryLength} = $fieldLength;
	$self->{_SummaryHeaders} = [ "Latency", "Percentage" ];
	$self->{_FieldHeaders} = [ "Time", "Latency" ];
	$self->{_FieldFormat} = [ "%${fieldLength}f", "%${fieldLength}f" ];

	my $file = "$reportDir/read-latency-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} elsif (-e "$file.gz") {
		open(INPUT, "gunzip -c $file.gz|") || die("Failed to open $file.gz: $!\n");
	} else {
		$file = "$reportDir/write-latency-$testName-$testBenchmark";
		if (-e $file) {
			open(INPUT, $file) || die("Failed to open $file: $!\n");
		} elsif (-e "$file.gz") {
			open(INPUT, "gunzip -c $file.gz|") || die("Failed to open $file.gz: $!\n");
		} else {
			die("Failed to find any file for processing\n");
		}
	}

	while (<INPUT>) {
		my ($timestamp, $latency) = split(/\s/, $_);
		if ($start_timestamp == 0) {
			$start_timestamp = $timestamp;
		}
		push @{$self->{_ResultData}},
			[ $timestamp - $start_timestamp,
		  	  $latency
			];
	}
}

1;
