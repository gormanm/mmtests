# ExtractHighalloc.pm
package MMTests::ExtractHighalloc;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract);
use strict;

use constant DATA_HIGHALLOC => 500;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractHighalloc",
		_DataType    => DATA_HIGHALLOC,
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

my @_workloads;

sub printDataType() {
	print "PercentageAllocated";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $lastWorkload = "";

	open(WORKLOG, "$reportDir/noprofile/mmtests.log") || die("Failed to open mmtests.log");
	while (!eof(WORKLOG)) {
		my $line = <WORKLOG>;
		if ($line =~ /Background workload: ([a-z-]+) pid [0-9]+, highalloc pass ([0-9]+)/) {
			if ($lastWorkload ne "$1") {
				push @_workloads, "$1";
			}
			$lastWorkload = $1;
		}
	}

	$self->SUPER::initialise();

	$self->{_TestName} = $testName;
	my $fieldLength = $self->{_FieldLength} = 25;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%${fieldLength}d", "%$fieldLength.2f" , "%${fieldLength}.3f" ];
	$self->{_FieldHeaders} = [ "Workload", "Op" ];
	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ "Workload", "Op" ];
}

sub printSummary() {
	my ($self, $subHeading) = @_;
	$self->printReport();
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);

	foreach my $workload (@_workloads) {
		my @files = <$reportDir/noprofile/highalloc-$workload-*.log>;
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
		push @{$self->{_ResultData}}, [ "$workload-pass", $iterations ];
		push @{$self->{_ResultData}}, [ "$workload-success", $nr_success * 100 / $nr_attempt ];
		push @{$self->{_ResultData}}, [ "$workload-mean-lat", calc_mean(@latencies) ];
	}

	return 1;
}

1;
