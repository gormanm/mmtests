# NumaConvergence.pm
#
# This module tracks NUMA hinting faults over time and can determine if
# a workload has converged or not.

package MMTests::MonitorNumaconvergence;
use MMTests::Monitor;
our @ISA    = qw(MMTests::Monitor);
use strict;

my $windowSize = 2000000;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "MonitorDuration",
		_DataType    => MMTests::Monitor::MONITOR_NUMA_CONVERGENCE,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self) = @_;
	$self->SUPER::initialise();

	my @window;
	$window[$windowSize] = 0;
	my $fieldLength = 12;
	$self->{_Window} = \@window;
	$self->{_FieldLength} = 12;
	$self->{_FieldFormat} = [ "%${fieldLength}d", "%${fieldLength}.4f" ];
	$self->{_FieldHeaders} = [ "time", "convergence" ];
}

sub currentConvergence()
{
	my ($self) = @_;
	my $window = $self->{_Window};

	my $faults_local = 0;
	my $faults_remote = 0;
	for (my $i = 0; $i < $windowSize; $i++) {
		if ($window->[$i] == 1) {
			$faults_remote++;
		} else {
			$faults_local++;
		}
	}

	return $faults_local / $windowSize;
}

sub nextWindowIndex()
{
	my ($self) = @_;

	$self->{_WindowIndex}++;
	if ($self->{_WindowIndex} == $windowSize) {
		$self->{_WindowIndex} = 0;
	}
}

sub parseVMStat($)
{
	my ($self, $vmstatOutput) = @_;
	my ($numa_faults, $numa_faults_local);
	my $window = $self->{_Window};

	foreach my $line (split(/\n/, $_[1])) {
		my ($stat, $value) = split(/\s/, $line);
		if ($stat eq "numa_hint_faults") {
			$numa_faults = $value;
		}
		if ($stat eq "numa_hint_faults_local") {
			$numa_faults_local = $value;
		}
	}

	my $faults;
	my $faults_local;
	my $faults_remote;
	if ($self->{_LastNumaFaults}) {
		$faults = $numa_faults - $self->{_LastNumaFaults};
		$faults_local = $numa_faults_local - $self->{_LastNumaFaultsLocal};
		$faults_remote = $faults - $faults_local;
	}
	$self->{_LastNumaFaults} = $numa_faults;
	$self->{_LastNumaFaultsLocal} = $numa_faults_local;

	while ($faults_remote || $faults_local) {
		if ($faults_remote) {
			$window->[$self->{_WindowIndex}] = 1;
			$faults_remote--;
			$self->nextWindowIndex();
		}
		if ($faults_local) {
			$window->[$self->{_WindowIndex}] = 0;
			$faults_local--;
			$self->nextWindowIndex();
		}
	}
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printGeneric($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractReport($$$$$) {
	my ($self, $reportDir, $testName, $testBenchmark) = @_;
	my $vmstat = "";
	my $timestamp = 0;
	my $start_timestamp = 0;

	my $file = "$reportDir/proc-vmstat-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file = $file . ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
	}
	while (<INPUT>) {
		if ($_ =~ /^time: ([0-9]+)/) {
			if ($start_timestamp == 0) {
				$start_timestamp = $1;
			}
			$timestamp = $1;
			if ($vmstat ne "") {
				$self->parseVMStat($vmstat);
				$vmstat = "";
				push @{$self->{_ResultData}},
					[ $timestamp - $start_timestamp,
					  $self->currentConvergence()
					];
			}
			next;
		}
		$vmstat .= $_;
	}
}

1;
