# ExtractAim9.pm
package MMTests::ExtractAim9;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

use constant DATA_AIM9 => 600;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractAim9",
		_DataType    => DATA_AIM9,
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "Operations/sec";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%${fieldLength}d", "%$fieldLength.2f" , "%${fieldLength}.3f" ];
	$self->{_FieldHeaders} = [ "Test", "Ops/sec" ];
	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ "Test", "Min", "Mean", "Stddev", "Max" ];
	$self->{_Workloads} = [ "page_test", "brk_test", "exec_test", "fork_test" ];
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self, $reportDir) = @_;
	my @data = @{$self->{_ResultData}};
	my $fieldLength = $self->{_FieldLength};
	my @_workloads = @{$self->{_Workloads}};

	foreach my $workload (@_workloads) {
		my @units;
		my @row;
		my $iterations = 0;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$workload") {
				push @units, @{$row}[2];
				$iterations++;
			}
		}
		push @row, $workload;
		foreach my $funcName ("calc_min", "calc_mean", "calc_stddev", "calc_max") {
			no strict "refs";
			push @row, &$funcName(@units);
		}
		push @{$self->{_SummaryData}}, \@row;
	}
	return 1;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @_workloads = @{$self->{_Workloads}};

	# List of report files, sort them to be purty
	my @files = <$reportDir/noprofile/aim9-*>;
	@files = sort {
		my ($dummy, $aIndex) = split(/-([^-]+)$/, $a);
		my ($dummy, $bIndex) = split(/-([^-]+)$/, $b);
		$aIndex <=> $bIndex;
	} @files;

	# Multiple reads of the same file, don't really care as this is hardly
	# performance critical code.
	foreach my $workload (@_workloads) {
		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $iteration = $split[-1];

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ =~ /$workload/) {
					my @elements = split(/\s+/, $_);
					push @{$self->{_ResultData}}, [ $workload, $iteration, $elements[6] ];
				}
			}
			close(INPUT);
		}
	}
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printGeneric($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

1;
