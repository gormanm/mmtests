# MonitorNumausage.pm

package MMTests::MonitorNumanodeusage;
use MMTests::SummariseMonitor;
use MMTests::NUMA;
our @ISA    = qw(MMTests::SummariseMonitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "MonitorNumanodeusage",
		_FieldLength => 18,
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName, $format, $subHeading) = @_;

	if ($subHeading eq "") {
		$subHeading = "Usage";
	}
	die if $subHeading ne "Usage" && $subHeading ne "MemoryBalance";

	if ($subHeading eq "Usage") {
		$self->{_DataType} = DataTypes::DATA_SIZE_BYTES;
	} else {
		$self->{_DataType} = DataTypes::DATA_BALANCE;
		$self->{_PlotYaxis} = "Memory Balance";
	}

	$self->SUPER::initialise($reportDir, $testName, $format, $subHeading);
}

sub extractReport($$$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading) = @_;
	my $timestamp = 0;
	my $start_timestamp = 0;

	if ($subHeading eq "") {
		$subHeading = "Usage";
	}

	my $file = "$reportDir/numa-meminfo-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file = $file . ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
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
