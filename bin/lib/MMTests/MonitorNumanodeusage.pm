# MonitorNumausage.pm

package MMTests::MonitorNumanodeusage;
use MMTests::Monitor;
our @ISA    = qw(MMTests::Monitor);
use strict;

my $windowSize = 20000;

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
	$self->{_PrintHandler}->printGeneric($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractReport($$$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading) = @_;
	my $vmstat = "";
	my $timestamp = 0;
	my $start_timestamp = 0;

	my $file = "$reportDir/numa-meminfo-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file = $file . ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	my $buildingHeader = 1;
	my @row;
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
			if ($#row > 0) {
				push @{$self->{_ResultData}}, [ @row ];

				$#row = -1;
				$buildingHeader = 0;
			}
			push @row, ($timestamp - $start_timestamp);
			next;
		}
		if ($_ =~ /^Node ([0-9]+) MemUsed:\s+([0-9]*)/) {
			push @row, $2 * 1024;
			if ($buildingHeader) {
				push @header, "Node$1";
				push @format, "%${fieldLength}d";
			}
		}
	}

	$self->{_FieldHeaders} = [ @header ];
	$self->{_FieldFormat} = [ @format ];
}

1;
