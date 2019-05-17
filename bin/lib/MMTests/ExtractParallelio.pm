# ExtractParallelio.pm
package MMTests::ExtractParallelio;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractParallelio",
		_DataType    => DataTypes::DATA_OPS_PER_SECOND,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $lastIOStep = -1;
	my @ioSteps;
	my @ioSizes;
	my $workload;

	# Read the IO steps and workload type
	my $file = "$reportDir/workload-durations.log";
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
	$file = "$reportDir/io-durations.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my @elements = split(/\s/);
		$ioSizes[$elements[0]] = (int $elements[1] / 1048576) . "M";
	}
	close(INPUT);

	# Read the workload performance data
	if ($workload eq "memcachetest") {
		foreach my $ioStep (@ioSteps) {
			my @reportDirs = <$reportDir/memcachetest-$ioStep-*>;
			my $minOps = -1;
			my $iteration = 0;

			foreach my $reportDir (@reportDirs) {
				my $ops;

				my $file = "$reportDir/mmtests.log";
				if (-e $file) {
					open(INPUT, $file) || die("Failed to open $file");
				} else {
					$file .= ".gz";
					open(INPUT, "gunzip -c $file|") || die("Failed to open $file");
				}
				while (!eof(INPUT)) {
					my $line = <INPUT>;
					if ($line =~ /ops\/sec: ([0-9]+)/) {
						$ops = $1;
					}
				}
				close(INPUT);

				$iteration++;
				$self->addData("memcachetest-$ioSizes[$ioStep]", $iteration, $ops);
			}
		}
	} else {
		die("Unable to handle parallel workload memcachetest");
	}
}

1;
