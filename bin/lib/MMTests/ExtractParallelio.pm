# ExtractParallelio.pm
package MMTests::ExtractParallelio;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractParallelio",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	$self->{_FieldLength} = 18;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%${fieldLength}d" ];
	$self->{_FieldHeaders}[0] = "Operation";
	$self->{_FieldHeaders}[1] = "Ops";
	$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub printSummary() {
	my ($self) = @_;

	$self->printReport();
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $lastIOStep = -1;
	my @ioSteps;
	my @ioSizes;
	my @ioMinIteration;
	my $workload;
	
	# Read the IO steps and workload type
	my $file = "$reportDir/noprofile/workload-durations.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my @elements = split(/\s/);
		$workload = $elements[0];
		if ($lastIOStep != $elements[1]) {
			push @ioSteps, $elements[1];
		}
		$lastIOStep = $elements[1];
	}
	close(INPUT);

	# Read the corresponding IO sizes
	$ioSizes[0] = "0M";
	$file = "$reportDir/noprofile/io-durations.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my @elements = split(/\s/);
		$ioSizes[$elements[0]] = (int $elements[1] / 1048576) . "M";
	}
	close(INPUT);

	# Read the workload performance data
	if ($workload eq "memcachetest") {
		foreach my $ioStep (@ioSteps) {
			my @reportDirs = <$reportDir/noprofile/memcachetest-$ioStep-*>;
			my $minOps = -1;
			my $minIteration;
			my $iteration = 0;

			foreach my $reportDir (@reportDirs) {
				my $ops;

				my $file = "$reportDir/noprofile/mmtests.log";
				open(INPUT, $file) || die("Failed to open $file");
				while (!eof(INPUT)) {
					my $line = <INPUT>;
					if ($line =~ /ops\/sec: ([0-9]+)/) {
						$ops = $1;
					}
				}
				close(INPUT);

				$iteration++;
				if ($minOps == -1 || $ops < $minOps) {
					$minOps = $ops;
					$minIteration = $iteration;
				}
			}

			die("Unable to find minops") if $minOps == -1;
			push @{$self->{_ResultData}}, [ "memcachetest-$ioSizes[$ioStep]", $minOps ];
			push @{$self->{_CompareOpsRow}}, "pdiff";
			$ioMinIteration[$ioStep] = $minIteration;
		}
	} else {
		die("Unable to handle parallel workload memcachetest");
	}

	# Read the IO durations
	$file = "$reportDir/noprofile/io-durations.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my @elements = split(/\s/);

		if ($ioMinIteration[$elements[0]] == $elements[2]) {
			push @{$self->{_ResultData}}, [ "io-duration-$ioSizes[$elements[0]]", $elements[3] ];
			push @{$self->{_CompareOpsRow}}, "pndiff";
		}
	}
	close(INPUT);

	# Read the VM Stats
	my (@swapInOut, @swapIns, @minorFaults, @majorFaults);
	foreach my $ioStep (@ioSteps) {
		my $readingBefore;

		my $file = "$reportDir/noprofile/vmstat-$workload-$ioStep-$ioMinIteration[$ioStep].log";
		open(INPUT, $file) || die("Failed to open $file");
		while (!eof(INPUT)) {
			my $line = <INPUT>;

			if ($line =~ /^start:/) {
				$readingBefore = 1;
				next;
			}

			if ($line =~ /^end:/) {
				$readingBefore = 0;
				next;
			}

			my @elements = split(/\s/, $line);
			if ($readingBefore) {
				$elements[1] = -$elements[1];
			}

			if ($elements[0] eq "pswpin") {
				$swapInOut[$ioStep] += $elements[1];
				$swapIns[$ioStep] += $elements[1];
			}
			if ($elements[0] eq "pswpout") {
				$swapInOut[$ioStep] += $elements[1];
			}
			if ($elements[0] eq "pgmajfault") {
				$majorFaults[$ioStep] += $elements[1];
				$minorFaults[$ioStep] -= $elements[1];
			}
			if ($elements[0] eq "pgfault") {
				$minorFaults[$ioStep] += $elements[1];
			}
		}
	}
	foreach my $ioStep (@ioSteps) {
		push @{$self->{_ResultData}}, [ "swaptotal-$ioSizes[$ioStep]", $swapInOut[$ioStep] ];
		push @{$self->{_CompareOpsRow}}, "pndiff";
	}
	foreach my $ioStep (@ioSteps) {
		push @{$self->{_ResultData}}, [ "swapin-$ioSizes[$ioStep]", $swapIns[$ioStep] ];
		push @{$self->{_CompareOpsRow}}, "pndiff";
	}
	foreach my $ioStep (@ioSteps) {
		push @{$self->{_ResultData}}, [ "minorfaults-$ioSizes[$ioStep]", $minorFaults[$ioStep] ];
		push @{$self->{_CompareOpsRow}}, "pndiff";
	}
	foreach my $ioStep (@ioSteps) {
		push @{$self->{_ResultData}}, [ "majorfaults-$ioSizes[$ioStep]", $majorFaults[$ioStep] ];
		push @{$self->{_CompareOpsRow}}, "pndiff";
	}
}

1;
