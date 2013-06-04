# MonitorNumausage.pm

package MMTests::MonitorNumanodeusage;
use MMTests::Monitor;
use VMR::NUMA;
our @ISA    = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "MonitorDuration",
		_DataType    => MMTests::Monitor::MONITOR_NUMA_USAGE,
		_ResultData  => []
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

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub printDataType() {
	my ($self) = @_;

	print "Nodestat,Time,$self->{_Heading}\n";
}

sub extractReport($$$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading) = @_;
	my $vmstat = "";
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

	my $buildingHeader = 1;
	my @row;
	my @nodeUsage;
	my @nodeSize;
	my @header;
	my @format;
	my $fieldLength = $self->{_FieldLength};
	while (<INPUT>) {
		if ($_ =~ /^time: ([0-9]+)/) {
			if ($start_timestamp == 0) {
				$start_timestamp = $1;
				push @header, "Time";
				push @format, "%${fieldLength}d";
			}
			$timestamp = $1;
			if ($#nodeUsage > 0) {
				if ($subHeading eq "Usage") {
					push @{$self->{_ResultData}}, [ ( @row, @nodeUsage ) ];
				} else {
					my @tuples;
					for (my $i = 0; $i <= $#nodeUsage; $i++) {
						push @tuples, $nodeUsage[$i];
						push @tuples, $nodeSize[$i];
					}
					push @{$self->{_ResultData}}, [ ( @row, numa_memory_balance(@tuples) ) ];
				}

				$#nodeUsage = -1;
				$#nodeSize  = -1;
				$#row = -1;
				$buildingHeader = 0;
			}
			push @row, ($timestamp - $start_timestamp);
			next;
		}
		if ($_ =~ /^Node ([0-9]+) MemUsed:\s+([0-9]*)/) {
			push @nodeUsage, $2 * 1024;
			if ($buildingHeader) {
				if ($subHeading eq "Usage") {
					push @header, "Node$1";
					push @format, "%${fieldLength}d";
				} else {
					push @header, "MemoryBalance";
					push @format, "%${fieldLength}.6f";
					$buildingHeader = 0;
				}
			}
		}
		if ($_ =~ /^Node ([0-9]+) MemTotal:\s+([0-9]*)/) {
			push @nodeSize, $2 * 1024;
		}
	}

	$self->{_FieldHeaders} = [ @header ];
	$self->{_FieldFormat} = [ @format ];
}

1;
