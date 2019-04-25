# ExtractHighalloc.pm
package MMTests::ExtractHighalloc;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractHighalloc",
		_DataType    => DataTypes::DATA_SUCCESS_PERCENT,
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);

	my $fieldLength = $self->{_FieldLength} = 25;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Workload", "Op" ];
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my @_workloads;
	my $lastWorkload = "";

	open(WORKLOG, "$reportDir/$profile/mmtests.log") || die("Failed to open mmtests.log");
	while (!eof(WORKLOG)) {
		my $line = <WORKLOG>;
		if ($line =~ /Background workload: ([a-z-]+) pid [0-9]+, highalloc pass ([0-9]+)/) {
			if ($lastWorkload ne "$1") {
				push @_workloads, "$1";
			}
			$lastWorkload = $1;
		}
	}

	foreach my $workload (@_workloads) {
		my @files = <$reportDir/$profile/highalloc-$workload-*.log>;
		my @latencies;
		my $iterations = 0;
		my $nr_success = 0;
		my $nr_attempt = 0;

		foreach my $file (@files) {
			$iterations++;

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ =~ /([0-9]+) (success|failure) ([0-9]+)/) {
					$nr_attempt++;
					if ($2 eq "success") {
						$nr_success++;
					}
					push @latencies, $3;
				}
			}
			close(INPUT);
		}
		$self->addData("$workload-pass", 0, $iterations );
		$self->addData("$workload-success", 0, $nr_success * 100 / $nr_attempt );
		$self->addData("$workload-mean-lat", 0, calc_mean(@latencies) );
	}

	return 1;
}

1;
