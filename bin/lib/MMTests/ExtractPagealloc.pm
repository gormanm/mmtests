# ExtractPagealloc.pm
package MMTests::ExtractPagealloc;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

use constant DATA_PAGEALLOC	=> 100;
use VMR::Stat;
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	my $fieldLength = $self->{_FieldLength} = 13;
	$self->SUPER::initialise();

	$self->{_DataType} = MMTests::Extract::DATA_TIME_CYCLES;
	$self->{_PlotXaxis}   = "MemSize";
	$self->{_PlotType} = "client-errorlines";
	$self->{_TestName} = $testName;
	$self->{_FilterNaN} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my %samples;

	my @orders;
	my @files = <$reportDir/noprofile/alloc-[0-9]*>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @orders, $split[-1];
	}
	@orders = sort @orders;

	my (@allocs, @frees, @batch_sizes);
	open(INPUT, "$reportDir/noprofile/pagealloc.log") || die("Failed to open pagealloc.log\n");

	while (!eof(INPUT)) {
		my $line = <INPUT>;
		my @elements = split(/\s+/, $line);

		my $order = $elements[1];
		my $batch = $elements[3];
		my $latency_alloc = $elements[5];
		my $latency_free = $elements[7];
		my $latency_total = $latency_alloc + $latency_free;

		$samples{$batch}++;
		if ($samples{$batch} == 1) {
			push @batch_sizes, $batch;
		}
		if ($samples{$batch} >= 3) {
			push @{$self->{_ResultData}}, ["alloc-odr$order-$batch", $samples{$batch} - 3, $latency_alloc];
			push @{$self->{_ResultData}}, ["free-odr$order-$batch", $samples{$batch} - 3, $latency_free];
			push @{$self->{_ResultData}}, ["total-odr$order-$batch", $samples{$batch} - 3, $latency_total];
		}
	}

	my @ops;
	foreach my $operation ("alloc", "free", "total") {
		foreach my $order (@orders) {
			foreach my $batch_size (@batch_sizes) {
				push @ops, "$operation-odr$order-$batch_size";
			}
		}
	}
	$self->{_Operations} = \@ops;
}

1;
