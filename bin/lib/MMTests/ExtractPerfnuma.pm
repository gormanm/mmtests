# ExtractPerfnuma.pm
package MMTests::ExtractPerfnuma;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractPerfnuma";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_FieldLength} = 34;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @convergances;

	my @files = <$reportDir/*-1.log>;
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

		my @files = <$reportDir/$convergance-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /\s+([0-9.]+), secs,\s+NUMA-convergence-latency/) {
					$self->addData("converged-$convergance", $iteration, $1);
				}
				if ($line =~ /\s+([0-9.]+), GB\/sec,\s+thread-speed/) {
					$self->addData("threadspeed-$convergance", $iteration, $1);
				}
				if ($line =~ /\s+([0-9.]+), GB\/sec,\s+total-speed/) {
					$self->addData("totalspeed-$convergance", $iteration, $1);
				}
			}
			close(INPUT);
			$iteration++;
		}
	}

	my @ops;
	foreach my $heading ("converged", "threadspeed", "totalspeed") {
		for my $convergance (@convergances) {
			push @ops, "$heading-$convergance";
		}
	}
	$self->{_Operations} = \@ops;
}

1;
