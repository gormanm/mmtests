# ExtractAim9.pm
package MMTests::ExtractAim9;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractAim9";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_Operations} = [ "page_test", "brk_test", "exec_test", "fork_test" ];

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	# List of report files, sort them to be purty
	my @files = <$reportDir/aim9-*>;
	@files = sort {
		my ($dummy, $aIndex) = split(/-([^-]+)$/, $a);
		my ($dummy, $bIndex) = split(/-([^-]+)$/, $b);
		$aIndex <=> $bIndex;
	} @files;

	# Multiple reads of the same file, don't really care as this is hardly
	# performance critical code.
	foreach my $workload (@{$self->{_Operations}}) {
		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $iteration = $split[-1];

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ =~ /$workload/) {
					my @elements = split(/\s+/, $_);
					$self->addData($workload, $iteration, $elements[6]);
				}
			}
			close(INPUT);
		}
	}
}

1;
