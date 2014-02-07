# ExtractStutter.pm
package MMTests::ExtractStutter;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 

use strict;
my @_threads;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractStutter",
		_DataType    => MMTests::Extract::DATA_WALLTIME,
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	print "WallTime,Sample,Time"
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);
	my $fieldLength = 12;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%${fieldLength}.2f" ];
}

sub extractSummary() {
        my ($self) = @_;
        my @latencyData = @{$self->{_LatencyData}};
        my @tputData = @{$self->{_ThroughputData}};
        my @opList = ("min", "mean", "stddev", "max");

	push @{$self->{_SummaryData}}, [ ">5ms Delays", $self->{_DelayedSamples} ];
	foreach my $opName (@opList) {
		no strict "refs";

		my @summaryRow;
		my $funcName = "calc_$opName";
		push @summaryRow, "Mmap $opName";
		push @summaryRow, &$funcName(@latencyData);

		push @{$self->{_SummaryData}}, \@summaryRow;
	}

	my $quartiles = calc_quartiles(@latencyData);
	push @{$self->{_SummaryData}}, [ "Mmap 90%", $$quartiles[90] ];
	push @{$self->{_SummaryData}}, [ "Mmap 93%", $$quartiles[93] ];
	push @{$self->{_SummaryData}}, [ "Mmap 95%", $$quartiles[95] ];
	push @{$self->{_SummaryData}}, [ "Mmap 99%", $$quartiles[99] ];

	push @{$self->{_SummaryData}}, [ "Ideal  Tput", $self->{_BestThroughput} ];
	foreach my $opName (@opList) {
		no strict "refs";

		my @summaryRow;
		my $funcName = "calc_$opName";
		push @summaryRow, "Tput $opName";
		push @summaryRow, &$funcName(@tputData);

		push @{$self->{_SummaryData}}, \@summaryRow;
	}
	return 1;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);

	# Extract parallel mmap latency
	my $file = "$reportDir/noprofile/mmap-latency.log";
	my $nr_samples = 1;
	my $nr_delayed = 0;
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my ($instances, $latency) = split(/ /);
		for (my $i = 0; $i < $instances; $i++) {
			push @{$self->{_ResultData}}, [$nr_samples++, $latency];
			push @{$self->{_LatencyData}}, $latency / 1000000;
		}
		if ($latency > 5000000) {
			$nr_delayed += $instances;
		}
	}
	close(INPUT);
	$self->{_DelayedSamples} = $nr_delayed;

	# Extract calibration write test throughput
	my $file = "$reportDir/noprofile/calibrate.time";
	open(INPUT, $file) || die("Failed to open $file\n");
	my @elements = split(/ /, <INPUT>);
	@elements = split(/:/, $elements[2]);
	$self->{_BestThroughput} = (1024) / ($elements[0] * 60 + $elements[1]);
	close(INPUT);

	# Extract filesize of write
	my $file = "$reportDir/noprofile/dd.filesize";
	open(INPUT, $file) || die("Failed to open $file\n");
	$self->{_FileSize} = <INPUT>;
	close(INPUT);

	# Extract calibration write test throughput
	my @files = <$reportDir/noprofile/time.*>;
	foreach my $file (@files) {
		open(INPUT, $file) || die("Failed to open $file\n");
		my @elements = split(/ /, <INPUT>);
		@elements = split(/:/, $elements[2]);
		push @{$self->{_ThroughputData}}, $self->{_FileSize} / 1048576 / ($elements[0] * 60 + $elements[1]);
		close(INPUT);
	}
}
1;
