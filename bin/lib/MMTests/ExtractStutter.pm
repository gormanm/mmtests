# ExtractStutter.pm
package MMTests::ExtractStutter;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 

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
        my @data = @{$self->{_MmapDelayData}};
        my @opList = ("min", "mean", "stddev", "max");

	push @{$self->{_SummaryData}}, [ "Mmap Delays", $self->{_DelayedSamples} ];
	foreach my $opName (@opList) {
		no strict "refs";

		my @summaryRow;
		my $funcName = "calc_$opName";
		push @summaryRow, "Mmap $opName";
		push @summaryRow, &$funcName(@data);

		push @{$self->{_SummaryData}}, \@summaryRow;
	}
	push @{$self->{_SummaryData}}, [ "Ideal  Tput", $self->{_BestThroughput} ];
	push @{$self->{_SummaryData}}, [ "Actual Tput", $self->{_TestThroughput} ];
	push @{$self->{_SummaryData}}, [ "%age   Tput", $self->{_TestThroughput} * 100 / $self->{_BestThroughput} ];
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
			if ($latency > 0) {
				push @{$self->{_MmapDelayData}}, $latency;
				$nr_delayed++
			}
			push @{$self->{_ResultData}}, [$nr_samples++, $latency];
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
	my $file = "$reportDir/noprofile/time.1";
	open(INPUT, $file) || die("Failed to open $file\n");
	my @elements = split(/ /, <INPUT>);
	@elements = split(/:/, $elements[2]);
	$self->{_TestThroughput} = $self->{_FileSize} / 1048576 / ($elements[0] * 60 + $elements[1]);
	close(INPUT);
}
1;
