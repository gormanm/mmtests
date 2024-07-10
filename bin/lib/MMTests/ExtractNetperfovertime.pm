# ExtractNetperfovertime.pm
package MMTests::ExtractNetperfovertime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractNetperfovertime";
	$self->{_DataType}   = DataTypes::DATA_MBITS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $filter_band = 0.75;

	open (INPUT, "$reportDir/protocols");
	my $protocol = <INPUT>;
	chomp($protocol);
	close(INPUT);

	my @sizes;
	my @files = <$reportDir/$protocol-*.1>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $size = $elements[-1];
		$size =~ s/\.1$//;
		push @sizes, $size;
	}
	@sizes = sort {$a <=> $b} @sizes;

	my %nr_samples;
	my %nr_filtered;

	my $loss;
	foreach my $size (@sizes) {
		my $file = "$reportDir/$protocol-$size.log";
		my $iteration = 0;
		my @samples;

		foreach $file (<$reportDir/$protocol-$size.*>) {
			my $send_tput = 0;
			my $recv_tput = 0;
			my $skip = 0;
			

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;

				next if ($line !~ /^Interim/);
				my ($tput, $interval);
				($_, $_, $tput, $_, $_, $interval, $_) = split(/\s+/, $line);
				$tput = $tput / $interval;
				push @samples, $tput;
			}
			close(INPUT);
		}

		my $hmean = calc_hmean(\@samples);
		my $min_filter = $hmean * (1 - $filter_band);
		my $max_filter = $hmean * (1 + $filter_band);

		$nr_samples{$size} = $#samples;
		foreach my $sample (@samples) {
			if ($sample >= $min_filter && $sample <= $max_filter) {
				$self->addData($size, ++$iteration, $sample);
			} else {
				$nr_filtered{$size}++
			}
		}
	}

	$self->{_Operations} = \@sizes;

	if ($filter_band != 1) {
		my @elements = split(/\//, $reportDir);
		printf("Filtered %20s HMean +/- %d%%\n", $elements[1], ($filter_band * 100));
		foreach my $size (@sizes) {
			printf("%6d %4d/%4d (%5.2f%%)\n", $size, $nr_filtered{$size}, $nr_samples{$size}, $nr_filtered{$size}*100/$nr_samples{$size});
		}
		print("\n");
	}
}

1;
