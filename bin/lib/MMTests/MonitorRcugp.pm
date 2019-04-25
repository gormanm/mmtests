# MonitorRcugp.pm
package MMTests::MonitorRcugp;
use MMTests::Monitor;
use MMTests::Stat;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorRcugp",
		_DataType      => MMTests::Monitor::MONITOR_READLATENCY,
		_MultiopMonitor => 1
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
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Flavor", "Time", "completedCumulative" ];
	$self->{_TestName} = $testName;
}

my %rcuFlavours;

sub extractSummary() {
	my ($self, $subheading) = @_;
	my %data = %{$self->dataByOperation()};

	my $fieldLength = 12;
	$self->{_SummaryHeaders} = [ "Statistic", "Mean", "Max", "Total" ];
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.2f", ];

	foreach my $rcuFlavour (sort keys %rcuFlavours) {
		my @gpCompleted;
		my ($lastTime, $lastCompleted);

		$lastTime = 0;
		$lastCompleted = 0;
		foreach my $rowRef (@{$data{$rcuFlavour}}) {
			my @row = @{$rowRef};

			if ($row[1] > 0) {
				push @gpCompleted, ($row[2] - $lastCompleted) / ($row[1] - $lastTime);
			}
			$lastTime = $row[1];
			$lastCompleted = $row[2];
		}

		my $meanCompleted  = calc_amean(\@gpCompleted);
		my $maxCompleted   = calc_max(@gpCompleted);

		push @{$self->{_SummaryData}}, [ "$rcuFlavour-gpCompleted", $meanCompleted, $maxCompleted, $lastCompleted ];
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
					$self->addData($rcuFlavour,
						  $thisGrace{"timestamp"} - $startTimestamp,
						  $thisGrace{"$rcuFlavour-gpCompleted"} - $firstGrace{"$rcuFlavour-gpCompleted"});
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
