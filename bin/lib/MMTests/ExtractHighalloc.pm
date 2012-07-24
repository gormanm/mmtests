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
	my ($self, $reportDir) = @_;

	my @files = <$reportDir/noprofile/workload-*-results.log>;
	foreach my $file (@files) {
		$file =~ s/.*\///;
		$file =~ s/workload-//;
		$file =~ s/-results.log//;
		push @_workloads, $file;
	}
	@_workloads = sort { $a <=> $b } @_workloads;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 16;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%${fieldLength}d", "%$fieldLength.2f" , "%${fieldLength}.3f" ];
	$self->{_FieldHeaders} = [ "Workload", "Iteration", "Success" ];
	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ "Workload", "Iterations", "Min", "Mean", "Stddev", "Max" ];
}

sub printSummary() {
	my ($self, $reportDir) = @_;
	my @data = @{$self->{_ResultData}};
	my $fieldLength = $self->{_FieldLength};
	my $column = $self->{_SummariseColumn};

	foreach my $workload (@_workloads) {
		my @units;
		my $iterations = 0;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$workload") {
				push @units, @{$row}[2];
				$iterations++;
			}
		}
		printf("%-${fieldLength}s", $workload);
		printf("%${fieldLength}d", $iterations);
		foreach my $funcName ("calc_min", "calc_mean", "calc_stddev", "calc_max") {
			no strict "refs";
			printf("%${fieldLength}.3f", &$funcName(@units));
		}
		printf("\n");
	}
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);

	foreach my $workload (@_workloads) {
		my @files = <$reportDir/noprofile/highalloc-$workload-*.log>;
		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $iteration = $split[-1];

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ =~ /^% Success/) {
					my @elements = split(/\s+/, $_);
					push @{$self->{_ResultData}}, [ $workload, $iteration, $elements[2] ];
				}
			}
			close(INPUT);
		}
	}
}

1;
