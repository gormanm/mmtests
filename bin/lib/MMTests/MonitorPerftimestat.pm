# MonitorPerftimestat.pm
package MMTests::MonitorPerftimestat;
use MMTests::Monitor;
use VMR::Stat;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorPerftimestat",
		_DataType      => MMTests::Monitor::MONITOR_PERFTIMESTAT,
		_ResultData    => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_FieldLength}   = 18;
	$self->{_TestName}      = $testName;
	$self->SUPER::initialise($reportDir, $testName);
}

my @fieldHeaders = ();
my %_colMap;

sub printDataType() {
	my ($self) = @_;
	my $headingName = $self->{_HeadingName};

	if ($headingName eq "cpu-migrations") {
		print "CPU Migrations,Events,Migrations\n";
	} elsif ($headingName eq "context-switches") {
		print "Context Switches,Time,Context Switches\n";
	} elsif ($headingName eq "task-clock") {
		print "Task Clock,Time,Task Clock\n";
	} elsif ($headingName eq "page-faults") {
		print "Page Faults,Events,Page Faults\n";
	} elsif ($headingName eq "cycles") {
		print "Cycles,Events,Cycles\n";
	} elsif ($headingName eq "instructions") {
		print "Instructions,Events,Instructions\n";
	} elsif ($headingName eq "branches") {
		print "Branches,Events,Branches\n";
	} elsif ($headingName eq "branch-misses") {
		print "Branch Misses,Events,Branch Misses";
	}
}

sub extractSummary() {
	my ($self, $subheading) = @_;
	my @data = @{$self->{_ResultData}};

	my $fieldLength = 18;
	$self->{_SummaryHeaders} = [ "Statistic", "Mean", "Max" ];
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.2f", ];

	# Array of potential headers and the samples
	my @headerCounters;
	my $index = 1;
	$headerCounters[0] = [];
	foreach my $header (@fieldHeaders) {
		next if $index == 0;
		$headerCounters[$index] = [];
		$index++;
	}

	# Collect the samples
	foreach my $rowRef (@data) {
		my @row = @{$rowRef};

		$index = 1;
		foreach my $header (@fieldHeaders) {
			next if $index == 0;
			push @{$headerCounters[$index]}, $row[$index];
			$index++;
		}
	}

	# Summarise
	$index = 1;
	foreach my $header (@fieldHeaders) {
		push @{$self->{_SummaryData}}, [ "$header",
			 calc_mean(@{@headerCounters[$index]}), calc_max(@{@headerCounters[$index]}) ];

		$index++;
	}

	return 1;
}

sub printPlot() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my $timestamp;
	my $start_timestamp = 0;

	# Figure out what file to open
	my $file = "$reportDir/perf-time-stat-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	# Read what counters ar active
	my $reading = 0;
	my $headingIndex = 0;
	if ($#fieldHeaders == -1) {
COLRD:		while (!eof(INPUT)) {
			my $line = <INPUT>;
			if ($line =~ /Performance counter stats for.*/) {
				$reading = 1;
				next;
			}
			next if $reading != 1;
			if ($line =~ /\s+([0-9,.]+)\s+([A-Za-z-]+).*/ && $line !~ /seconds time elapsed/) {
				$_colMap{$2} = ++$headingIndex;
				push @fieldHeaders, $2;
			}
			if ($line =~ /seconds time elapsed/) {
				last COLRD;
			}
		}
	}

	# Reopen file. Cannot seek a pipe
	my $file = "$reportDir/perf-time-stat-$testName-$testBenchmark";
	close(INPUT);
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	if ($subHeading ne "") {
		$self->{_FieldHeaders}  = [ "", "$subHeading" ];
		if (!defined $_colMap{$subHeading}) {
			die("Unrecognised heading $subHeading");
		}
		my $headingIndex = $_colMap{$subHeading};
		$self->{_HeadingIndex} = $_colMap{$subHeading};
		$self->{_HeadingName} = $subHeading;
	} else {
		$self->{_FieldHeaders}  = \@fieldHeaders;
	}

	# Read all counters
	my $timestamp;
	my $start_timestamp = 0;
	my @row;
	$headingIndex = 0;
	$reading = 0;
	while (!eof(INPUT)) {
		my $line = <INPUT>;

		if ($line =~ /^time: ([0-9]+)/) {
			if ($start_timestamp) {
				push @{$self->{_ResultData}}, [ @row ];
				$#row = -1;
			}

			$reading = 0;
			$timestamp = $1;
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			}
			push @row, $timestamp - $start_timestamp;
			$headingIndex = 0;
		}

		if ($line =~ /Performance counter stats for.*/) {
			$reading = 1;
			next;
		}
		next if $reading != 1;
		if ($line =~ /\s+([0-9,\.]+)\s+([A-Za-z-]+).*/) {
			my $counter = $1;
			$counter =~ s/,//g;
			$headingIndex++;
			if ($subHeading eq "" || $self->{_HeadingIndex} == $headingIndex) {
				push @row, $counter;
			}
		}
	}
}

1;
