# ExtractPagealloc.pm
package MMTests::ExtractPagealloc;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract);

use constant DATA_PAGEALLOC	=> 100;
use VMR::Stat;
use strict;

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
	my @orders;

	my @files = <$reportDir/noprofile/alloc-[0-9]*>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @orders, $split[-1];
	}
	@orders = sort @orders;
	$self->{_Orders} = \@orders;

	my $fieldLength = 17;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = ["Oper-Batch"];
	$self->{_FieldFormat} = [ "%${fieldLength}s" ];
	foreach my $order (@orders) {
		push @{$self->{_FieldHeaders}}, "order-$order";
		push @{$self->{_FieldFormat}}, "%${fieldLength}d";
	}

	$self->{_TestName} = $testName;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	$self->{_PlotLength} = $fieldLength;
	$self->{_PlotHeaders} = ["Batch", "Alloc", "Free"];
}

sub printDataType() {
	print "PageAlloc";
}

sub printReport() {
	my ($self) = @_;
	my @data = @{$self->{_ResultData}};
	my @orders = @{$self->{_Orders}};
	my @batches = @{$self->{_Batches}};
	my $operationIndex = 0;
	my $fieldLength = $self->{_FieldLength};
	my $samples = scalar @{$data[0][$orders[0]][1]};

	foreach my $operation ("alloc", "free", "total") {
		foreach my $batch (@batches) {
			for (my $i = 0; $i < $samples; $i++) {
				my @row;
				push @row, "$operation-$batch";

				foreach my $order (@orders) {
					push @row, $data[$operationIndex][$order][$batch][$i];
				}
				push @{$self->{_FlatResultData}}, \@row;
			}
		}
		$operationIndex++;
	}
	$self->{_PrintHandler}->printRow($self->{_FlatResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my @orders = @{$self->{_Orders}};
	my @batches = @{$self->{_Batches}};
	my $operationIndex = 0;

	foreach my $operation ("alloc", "free", "total") {
		foreach my $batch (@batches) {
			my (@means, @stddevs);
			my @row;
			foreach my $order (@orders) {
				$means[$order] = calc_trimoutlier_mean(@{$data[$operationIndex][$order][$batch]});
				$stddevs[$order] = calc_stddev(@{$data[$operationIndex][$order][$batch]});
			}

			push @row, "$operation-$batch";
			foreach my $order (@orders) {
				push @row, $means[$order];
			}
			push @{$self->{_SummaryData}}, \@row;

			if ($ENV{"MMTESTS_PAGEALLOC_PERCENTAGE"} ne "") {
				my @row;
				push @row, "$operation-$batch+-%age";

				foreach my $order (@orders) {
					if ($means[$order] == 0) {
						push @row, 0;
					} else {
						push @row, ($stddevs[$order]*100)/$means[$order];
					}
				}
				push @{$self->{_SummaryData}}, \@row;
			}
		}
		$operationIndex++;
	}

	return 1;
}

sub printPlot() {
	my ($self, $subheading) = @_;
	my $fieldLength = $self->{_PlotLength} - 1;
	my @data = @{$self->{_ResultData}};
	my @batches = @{$self->{_Batches}};

	my $order = $subheading;
	$order =~ s/order-//;

	foreach my $batch (@batches) {
		my $alloc_mean = calc_trimoutlier_mean(@{$data[0][$order][$batch]});
		my $free_mean = calc_trimoutlier_mean(@{$data[1][$order][$batch]});

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
	my @orders = @{$self->{_Orders}};
	my %hashBatches;

	foreach my $operation ("alloc", "free") {
		foreach my $order (@orders) {
			my $inputFile = "$reportDir/noprofile/$operation-$order";
			open(INPUT, $inputFile) || die ("Failed to open $inputFile");
			while (<INPUT>) {
				my ($batch, $latency) = split (/ /, $_);
				$hashBatches{$batch} = 1;
				chomp($latency);
				push @{$data[$operationIndex][$order][$batch]}, $latency;
			}
			close INPUT;
		}
		$operationIndex++;
	}

	# Calculate the totals operation
	my @batches = sort { $a <=> $b } keys(%hashBatches);
	$self->{_Batches} = \@batches;
	foreach my $batch (@batches) {
		foreach my $order (@orders) {
			my $total = 0;

			if (!defined($data[0][$order][$batch])) {
				next;
			}

			my @allocs = @{$data[0][$order][$batch]};
			my @frees  = @{$data[1][$order][$batch]};

			for (my $i = 0; $i <= $#allocs; $i++) {
				push @{$data[$operationIndex][$order][$batch]}, $allocs[$i] + $frees[$i];
			}
		}
	}
	$self->{_ResultData} = \@data;
}

1;
