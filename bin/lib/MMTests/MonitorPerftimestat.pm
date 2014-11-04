# MonitorPerftimestat.pm
package MMTests::MonitorPerftimestat;
use MMTests::Monitor;
use VMR::Report;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorPerftimestat",
		_DataType      => MMTests::Monitor::MONITOR_VMSTAT,
		_RowOrientated => 1,
		_ResultData    => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);
	$self->{_DataType}      = MMTests::Monitor::MONITOR_VMSTAT,
	$self->{_RowOrientated} = 1;
	$self->{_FieldLength}   = 18;
	$self->{_TestName}      = $testName;
}


my %_colMap;

sub printDataType() {
	my ($self) = @_;
	my $headingName = $self->{_HeadingName};

	if ($headingName eq "CPU-migrations") {
		print "CPU Migrations,Time,Migrations\n";
	} elsif ($headingName eq "context-switches") {
		print "Context Switches,Time,Context Switches\n";
	}
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my $timestamp;
	my $start_timestamp = 0;
	my @fieldHeaders = ("");

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
COLRD:	while (!eof(INPUT)) {
		my $line = <INPUT>;
		if ($line =~ /Performance counter stats for.*/) {
			$reading = 1;
			next;
		}
		next if $reading != 1;
		if ($line =~ /\s+([0-9,]+) ([A-Za-z-]+).*/) {
			$_colMap{$2} = ++$headingIndex;
			push @fieldHeaders, $2;
		}
		if ($line =~ /seconds time elapsed/) {
			
			last COLRD;
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
		if ($line =~ /\s+([0-9,]+) ([A-Za-z-]+).*/) {
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
