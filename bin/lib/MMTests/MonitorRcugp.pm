# MonitorRcugp.pm
package MMTests::MonitorRcugp;
use MMTests::Monitor;
use VMR::Report;
use VMR::Stat;
our @ISA = qw(MMTests::Monitor); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorRcugp",
		_DataType      => MMTests::Monitor::MONITOR_READLATENCY,
		_ResultData    => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	my $headingIndex = $self->{_HeadingIndex};

	print "Time,Time,Grace\n";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->SUPER::initialise();

	my $fieldLength = 12;
	$self->{_FieldLength} = 12;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%-${fieldLength}s", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "time", "rcu", "completedInterval", "completedCumulative" ];
	$self->{_SummaryHeaders} = [ "Statistic", "Mean", "Max", "Total" ];
	$self->{_TestName} = $testName;
}

my %rcuFlavours;

sub extractSummary() {
	my ($self, $subheading) = @_;
	my @data = @{$self->{_ResultData}};

	my $fieldLength = 12;
	$self->{_SummaryHeaders} = [ "Statistic", "Mean", "Max", "Total" ];
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.2f", ];

	foreach my $rcuFlavour (sort keys %rcuFlavours) {
		my @gpCompleted;
		my $totalCompleted;

		foreach my $rowRef (@data) {
			my @row = @{$rowRef};
			next if ($row[1] ne $rcuFlavour);

			push @gpCompleted, $row[2];
			$totalCompleted = $row[3];
		}

		my $meanCompleted  = calc_mean(@gpCompleted);
		my $maxCompleted   = calc_max(@gpCompleted);

		push @{$self->{_SummaryData}}, [ "$rcuFlavour-gpCompleted", $meanCompleted, $maxCompleted, $totalCompleted ];
	}

	return 1;
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my (%lastGrace, %thisGrace, %firstGrace);
	my $startTimestamp = 0;

	open (INPUT, "$reportDir/rcugp-$testName-$testBenchmark") ||
		die("rcugp-$testName-$testBenchmark does not exist");

	while (!eof(INPUT)) {
		my $line = <INPUT>;
		my $rcuFlavour;

		if ($line =~ /^time: ([0-9]+)/) {
			foreach $rcuFlavour (keys %rcuFlavours) {
				if (!defined $firstGrace{"$rcuFlavour-gpCompleted"}) {
					%firstGrace = %thisGrace;
				}
				if (defined $lastGrace{"timestamp"}) {
					my $nrSeconds = $thisGrace{"timestamp"} - $lastGrace{"timestamp"};
					push @{$self->{_ResultData}},
						[ $thisGrace{"timestamp"} - $startTimestamp,
					  	$rcuFlavour,
					  	($thisGrace{"$rcuFlavour-gpCompleted"} - $lastGrace{"$rcuFlavour-gpCompleted"}) / $nrSeconds,
						$thisGrace{"$rcuFlavour-gpCompleted"} - $firstGrace{"$rcuFlavour-gpCompleted"} ];
				}
			}
			%lastGrace = %thisGrace;
			$thisGrace{"timestamp"} = $1;
			if ($startTimestamp ==  0) {
				$startTimestamp = $thisGrace{"timestamp"};
			}
			next;
		}

		my @elements = split(/\s/, $line);
		$rcuFlavour = $elements[0];
		$rcuFlavours{$rcuFlavour} = 1;
		$thisGrace{"$rcuFlavour-gpCompleted"} = $elements[1];
		$thisGrace{"$rcuFlavour-gpCompleted"} =~ s/.*=//;
	}
}

1;
