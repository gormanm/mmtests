# ExtractPerfnuma.pm
package MMTests::ExtractPerfnuma;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractPerfnuma";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_FieldLength} = 34;
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @convergances;

	my @files = <$reportDir/$profile/*-1.log>;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		my $filename = $split[-1];
		$filename =~ s/-[0-9]+.log//;
		push @convergances, $filename;
	}
	@convergances = sort { $a cmp $b } @convergances;

	# Extract timing information
	foreach my $convergance (@convergances) {
		my $iteration = 0;

		my @files = <$reportDir/$profile/$convergance-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /\s+([0-9.]+) secs latency to NUMA-converge/) {
					push @{$self->{_ResultData}}, [ "converged-$convergance", $iteration, $1 ];
				}
				if ($line =~ /\s+([0-9.]+) secs slowest/) {
					push @{$self->{_ResultData}}, [ "slowest-$convergance", $iteration, $1 ];
				}
				if ($line =~ /\s+([0-9.]+) secs fastest/) {
					push @{$self->{_ResultData}}, [ "fastest-$convergance", $iteration, $1 ];
				}
			}
			close(INPUT);
			$iteration++;
		}
	}

	my @ops;
	foreach my $heading ("converged", "slowest", "fastest") {
		for my $convergance (@convergances) {
			push @ops, "$heading-$convergance";
		}
	}
	$self->{_Operations} = \@ops;
}

1;
