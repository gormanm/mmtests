# ExtractLinkbench.pm
package MMTests::ExtractLinkbench;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_TestName} = $testName;
	$self->{_ModuleName} = "ExtractLinkbench";
	$self->{_DataType}   = MMTests::Extract::DATA_OPS_PER_SECOND;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%$fieldLength.2f" , "%${fieldLength}.3f%%" ];
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Threads";
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tp, $name);
	my @threads;

	my @files = <$reportDir/noprofile/linkbench-request-*-1.log>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $thr = $elements[-2];
		$thr =~ s/.log//;
		push @threads, $thr;
	}

	foreach my $nthr (@threads) {
		my @files = <$reportDir/noprofile/linkbench-request-$nthr-*.log>;

		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $nr_samples = 0;

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /REQUEST PHASE COMPLETED. ([0-9]+) requests done in ([0-9]+) seconds. Requests\/second = ([0-9]+)/) {
					push @{$self->{_ResultData}}, [ $nthr, ++$nr_samples, $3 ];
				}
			}
			close INPUT;
		}
	}

	my @ops = sort {$a <=> $b} @threads;
	$self->{_Operations} = \@ops;
}
