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
	$self->{_PlotXaxis}  = "Clients";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/noprofile/hackbench.*>;
	my @threads;
	foreach my $file (@files) {
		my @split = split /\./, $file;
		push @threads, $split[-1];
	}
	@threads = sort { $a <=> $b} @threads;

	foreach my $thread (@threads) {
		my $file = "$reportDir/noprofile/hackbench.$thread";
		my $nr_samples = 0;
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			if ($_ !~ /^Time: (.*)/) {
				next;
			}
			my $walltime = $1;
			push @{$self->{_ResultData}}, [$thread, ++$nr_samples, $walltime];
		}
		close INPUT;
	}

	$self->{_Operations} = \@threads;
}
1;
