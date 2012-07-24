# ExtractPagealloc.pm
package MMTests::ExtractPagealloc;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 

use constant DATA_PAGEALLOC	=> 100;
use VMR::Stat;
use strict;

my @_orders;
my %_batches;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPagealloc",
		_DataType    => DATA_PAGEALLOC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}


sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	my @files = <$reportDir/noprofile/alloc-*>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @_orders, $split[-1];
	}
	@_orders = sort @_orders;

	my $fieldLength = 17;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = ["Oper-Batch"];
	foreach my $order (@_orders) {
		push @{$self->{_FieldHeaders}}, "order-$order";
	}

	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}s" ];
	$self->{_SummaryLength} = $fieldLength;
	$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	$self->{_PlotLength} = $fieldLength;
	$self->{_PlotHeaders} = ["Batch", "Alloc", "Free"];
	$self->{_PrintHandler} = MMTests::Print->new();
}

sub printDataType() {
	print "PageAlloc";
}

sub printReport() {
	my ($self) = @_;
	my @data = @{$self->{_ResultData}};
	my @batches = sort { $a <=> $b } keys(%_batches);
	my $operationIndex = 0;
	my $fieldLength = $self->{_FieldLength};
	my $samples = scalar @{$data[0][$_orders[0]][1]};

	foreach my $operation ("alloc", "free") {
		foreach my $batch (@batches) {
			for (my $i = 0; $i < $samples; $i++) {
				printf("%${fieldLength}s", "$operation-$batch");
				foreach my $order (@_orders) {
					printf("%${fieldLength}d",
						$data[$operationIndex][$order][$batch][$i]);
				}
				print "\n";
			}
		}
		$operationIndex++;
	}
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my @batches = sort { $a <=> $b } keys(%_batches);
	my $operationIndex = 0;

	foreach my $operation ("alloc", "free") {
		foreach my $batch (@batches) {
			my (@means, @stddevs);
			my @row;
			foreach my $order (@_orders) {
				$means[$order] = calc_mean(@{$data[$operationIndex][$order][$batch]});
				$stddevs[$order] = calc_stddev(@{$data[$operationIndex][$order][$batch]});
			}

			push @row, "$operation-$batch";
			foreach my $order (@_orders) {
				push @row, $means[$order];
			}
			push @{$self->{_SummaryData}}, \@row;

			my @row;
			push @row, "$operation-$batch+-%age";

			foreach my $order (@_orders) {
				push @row, ($stddevs[$order]*100)/$means[$order];
			}
			push @{$self->{_SummaryData}}, \@row;
		}
		$operationIndex++;
	}

	return 1;
}

sub printPlot() {
	my ($self, $subheading) = @_;
	my $fieldLength = $self->{_PlotLength} - 1;
	my @data = @{$self->{_ResultData}};
	my @batches = sort { $a <=> $b } keys(%_batches);

	my $order = $subheading;
	$order =~ s/order-//;

	foreach my $batch (@batches) {
		my $alloc_mean = calc_mean(@{$data[0][$order][$batch]});
		my $free_mean = calc_mean(@{$data[1][$order][$batch]});

		if ($alloc_mean =~ /\d/) {
			printf("%-${fieldLength}d %${fieldLength}.2f %${fieldLength}.2f\n",
				$batch, $alloc_mean, $free_mean)
		}
	}
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $file = "$reportDir/noprofile/time";
	my @data = ([]);
	my $operationIndex = 0;

	foreach my $operation ("alloc", "free") {
		foreach my $order (@_orders) {
			my $inputFile = "$reportDir/noprofile/$operation-$order";
			open(INPUT, $inputFile) || die ("Failed to open $inputFile");
			while (<INPUT>) {
				my ($batch, $latency) = split (/ /, $_);
				$_batches{$batch} = 1;
				chomp($latency);
				push @{$data[$operationIndex][$order][$batch]}, $latency;
			}
			close INPUT;
		}
		$operationIndex++;
	}
	$self->{_ResultData} = \@data;
}

1;
