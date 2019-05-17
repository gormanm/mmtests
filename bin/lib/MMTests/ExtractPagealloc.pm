# ExtractPagealloc.pm
package MMTests::ExtractPagealloc;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_DataType} = DataTypes::DATA_TIME_CYCLES;
	$self->{_FilterNaN} = 1;
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my %samples;

	my @orders;
	my @files = <$reportDir/alloc-[0-9]*>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @orders, $split[-1];
	}
	@orders = sort @orders;

	my (@allocs, @frees, @batch_sizes);
	open(INPUT, "$reportDir/pagealloc.log") || die("Failed to open pagealloc.log\n");

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
			$self->addData("alloc-odr$order-$batch", $samples{$batch} - 3, $latency_alloc);
			$self->addData("free-odr$order-$batch", $samples{$batch} - 3, $latency_free);
			$self->addData("total-odr$order-$batch", $samples{$batch} - 3, $latency_total);
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
