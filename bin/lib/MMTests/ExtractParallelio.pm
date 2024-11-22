# ExtractParallelio.pm
package MMTests::ExtractParallelio;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractParallelio",
		_PlotYaxis   => DataTypes::LABEL_OPS_PER_SECOND,
		_PreferredVal => "Higher",
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
	my $input = $self->SUPER::open_log("$reportDir/workload-durations.log");
	while (<$input>) {
		my @elements = split(/\s/);
		$workload = $elements[0];
		if ($lastIOStep != $elements[1]) {
			push @ioSteps, $elements[1];
		}
		$lastIOStep = $elements[1];
	}
	close($input);

	# Read the corresponding IO sizes
	$ioSizes[0] = "0M";
	$input = $self->SUPER::open_log("$reportDir/io-durations.log");
	while (<$input>) {
		my @elements = split(/\s/);
		$ioSizes[$elements[0]] = (int $elements[1] / 1048576) . "M";
	}
	close($input);

	# Read the workload performance data
	if ($workload eq "memcachetest") {
		foreach my $ioStep (@ioSteps) {
			my @reportDirs = <$reportDir/memcachetest-$ioStep-*>;
			my $minOps = -1;
			my $iteration = 0;

			foreach my $reportDir (@reportDirs) {
				my $ops;

				$input = $self->SUPER::open_log("$reportDir/logs/mmtests.log");
				while (!eof($input)) {
					my $line = <$input>;
					if ($line =~ /ops\/sec: ([0-9]+)/) {
						$ops = $1;
					}
				}
				close($input);

				$iteration++;
				$self->addData("memcachetest-$ioSizes[$ioStep]", $iteration, $ops);
			}
		}
	} else {
		die("Unable to handle parallel workload memcachetest");
	}
}

1;
