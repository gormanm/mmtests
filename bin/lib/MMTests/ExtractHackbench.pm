# ExtractHackbench.pm
package MMTests::ExtractHackbench;
use MMTests::SummariseMultiops;
use VMR::Report;
our @ISA = qw(MMTests::SummariseMultiops);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractHackbench";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Groups";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/noprofile/hackbench-*-1>;
	my @groups;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @groups, $split[-2];
	}
	@groups = sort { $a <=> $b} @groups;

	foreach my $group (@groups) {
		my $nr_samples = 0;
		foreach my $file (<$reportDir/noprofile/hackbench-$group-*>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ !~ /^Time: (.*)/) {
					next;
				}
				my $walltime = $1;
				push @{$self->{_ResultData}}, [$group, ++$nr_samples, $walltime];
			}
			close INPUT;
		}
	}

	$self->{_Operations} = \@groups;
}
1;
