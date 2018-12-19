# MonitorNumausage.pm

package MMTests::MonitorNumanodeusage;
use MMTests::Monitor;
use MMTests::NUMA;
our @ISA    = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "MonitorDuration",
		_DataType    => MMTests::Monitor::MONITOR_NUMA_USAGE,
		_ResultData  => [],
		_MultiopMonitor => 1
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self) = @_;
	$self->SUPER::initialise();

	my $fieldLength = 18;
	$self->{_FieldLength} = $fieldLength;
}

sub printDataType() {
	my ($self) = @_;

	print "Nodestat,Time,$self->{_Heading}\n";
}

sub extractReport($$$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading) = @_;
	my $timestamp = 0;
	my $start_timestamp = 0;

	if ($subHeading eq "") {
		$subHeading = "Usage";
	}

	die if $subHeading ne "Usage" && $subHeading ne "MemoryBalance";

	my $file = "$reportDir/numa-meminfo-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file = $file . ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	if ($subHeading eq "Usage") {
		$self->{_FieldHeaders} = [ "Node", "Time", "Bytes" ];
		$self->{_FieldFormat} = ["%${fieldLength}s", "%${fieldLength}d",
				 "%${fieldLength}d" ];
	} else {
		$self->{_FieldHeaders} = [ "Node", "Time", "MemoryBalance" ];
		$self->{_FieldFormat} = ["%${fieldLength}s", "%${fieldLength}d",
				 "%${fieldLength}.6f" ];
	}

	my @nodeUsage;
	my @nodeSize;
	while (<INPUT>) {
		if ($_ =~ /^time: ([0-9]+)/) {
			if ($start_timestamp == 0) {
				$start_timestamp = $1;
				$timestamp = $1;
				next;
			}
			if ($subHeading eq "MemoryBalance") {
				my @tuples;
				for (my $i = 0; $i <= $#nodeUsage; $i++) {
					push @tuples, $nodeUsage[$i];
					push @tuples, $nodeSize[$i];
				}
				$self->addData("Balance", $timestamp - $start_timestamp, numa_memory_balance(@tuples) );

				$#nodeUsage = -1;
				$#nodeSize  = -1;
			}
			$timestamp = $1;

			next;
		}
		if ($_ =~ /^Node ([0-9]+) MemUsed:\s+([0-9]*)/) {
			if ($subHeading eq "Usage") {
				$self->addData("Node$1", $timestamp - $start_timestamp, $2 * 1024 );
			} else {
				push @nodeUsage, $2 * 1024;
			}
		} elsif ($subHeading eq "MemoryBalance" &&
			 $_ =~ /^Node [0-9]+ MemTotal:\s+([0-9]*)/) {
			push @nodeSize, $1 * 1024;
		}
	}
}

1;
