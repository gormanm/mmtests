# NumaConvergence.pm
#
# This module tracks NUMA hinting faults over time and can determine if
# a workload has converged or not. Values tending towards 1 indicate that
# the majority of faults are local.

package MMTests::MonitorNumaconvergence;
use MMTests::SummariseMonitor;
our @ISA    = qw(MMTests::SummariseMonitor);
use strict;

my $windowSize = 20000;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "MonitorNumaconvergence",
		_PlotYaxis   => "Convergence",
		_DataType    => DataTypes::DATA_CONVERGENCE,
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName, $format, $subHeading) = @_;
	$self->SUPER::initialise($reportDir, $testName, $format, $subHeading);

	my @window;
	$window[$windowSize] = 0;
	$self->{_Window} = \@window;
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

	# Approximate to save memory
	$faults_local = int ($faults_local / 100);
	$faults_remote = int ($faults_remote / 100);

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

sub extractReport($$$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading) = @_;
	my $vmstat = "";
	my $timestamp = 0;
	my $start_timestamp = 0;

	my $file = "$reportDir/proc-vmstat-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file = $file . ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
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
				$self->addData("convergence",
					  $timestamp - $start_timestamp,
					  $self->currentConvergence());
			}
			next;
		}
		$vmstat .= $_;
	}
}

1;
