# ExtractAdrestia.pm
package MMTests::ExtractAdrestia;
use MMTests::SummariseMultiops;
use VMR::Report;
our @ISA = qw(MMTests::SummariseMultiops);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractAdrestia";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Arrival Time";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/noprofile/adrestia-*-1.log>;
	my @tmp;
	my @threads;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @tmp, $split[-3];
	}

	my @groups = do { my %seen; grep { !$seen{$_}++ } @tmp };

	foreach my $file (<$reportDir/noprofile/adrestia-$groups[0]-*-1.log>) {
		my @split = split /-/, $file;
		push @threads, $split[-2];
	}

	@groups = sort { $a <=> $b} @groups;
	@threads = sort { $a <=> $b} @threads;

	foreach my $group (@groups) {
		my $nr_samples = 0;
		foreach my $thread (@threads) {
			foreach my $file (<$reportDir/noprofile/adrestia-$group-$thread-*.log>) {
				my @split = split /-/, $file;

				open(INPUT, $file) || die("Failed to open $file\n");
				while (<INPUT>) {
					if ($_ !~ /^wakeup cost.*: (.*)us/) {
						next;
					}
					my $walltime = $1;
					push @{$self->{_ResultData}}, ["$thread-$group", ++$nr_samples, $walltime];
				}

				close INPUT;
			}
		}
	}

	my @ops;
	foreach my $metric (@threads) {
		foreach my $group (@groups) {
			push @ops, "$metric-$group";
		}
	}
	$self->{_Operations} = \@ops;
}
1;
