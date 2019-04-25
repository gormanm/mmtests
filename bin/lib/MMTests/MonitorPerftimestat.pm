# MonitorPerftimestat.pm
package MMTests::MonitorPerftimestat;
use MMTests::Monitor;
use MMTests::Stat;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorPerftimestat",
		_DataType      => MMTests::Monitor::MONITOR_PERFTIMESTAT,
		_MultiopMonitor => 1,
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

sub printDataType() {
	my ($self, $subHeading) = @_;

	if ($subHeading eq "cpu-migrations") {
		print "CPU Migrations,Events,Migrations\n";
	} elsif ($subHeading eq "context-switches") {
		print "Context Switches,Time,Context Switches\n";
	} elsif ($subHeading eq "task-clock") {
		print "Task Clock,Time,Task Clock\n";
	} elsif ($subHeading eq "page-faults") {
		print "Page Faults,Events,Page Faults\n";
	} elsif ($subHeading eq "cycles") {
		print "Cycles,Events,Cycles\n";
	} elsif ($subHeading eq "instructions") {
		print "Instructions,Events,Instructions\n";
	} elsif ($subHeading eq "branches") {
		print "Branches,Events,Branches\n";
	} elsif ($subHeading eq "branch-misses") {
		print "Branch Misses,Events,Branch Misses";
	}
}

sub extractSummary() {
	my ($self, $subheading) = @_;
	my %data = %{$self->dataByOperation()};

	my $fieldLength = 18;
	$self->{_SummaryHeaders} = [ "Statistic", "Mean", "Max" ];
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.2f", ];

	foreach my $header (keys %data) {
		my @samples = map {$_ -> [1]} @{$data{$header}};

		push @{$self->{_SummaryData}}, [ "$header",
			 calc_amean(\@samples), calc_max(\@samples) ];
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


	$self->{_FieldHeaders}  = [ "Op", "Time", "Value" ];

	# Read all counters
	my $timestamp;
	my $start_timestamp = 0;
	my $reading = 0;

	while (!eof(INPUT)) {
		my $line = <INPUT>;

		if ($line =~ /^time: ([0-9]+)/) {
			$reading = 0;
			$timestamp = $1;
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			}
		}

		if ($line =~ /Performance counter stats for.*/) {
			$reading = 1;
			next;
		}
		next if $reading != 1;
		next if $line =~ /seconds time elapsed/;
		if ($line =~ /\s+([0-9,\.]+)\s+([A-Za-z-]+).*/) {
			my ($counter, $heading) = ($1, $2);

			next if ($subHeading ne "" && $heading ne $subHeading);

			$counter =~ s/,//g;
			$self->addData($heading, $timestamp - $start_timestamp, $counter );
		}
	}
}

1;
