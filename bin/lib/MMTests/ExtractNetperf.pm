# ExtractNetperf.pm
package MMTests::ExtractNetperf;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractNetperf";
	$self->{_DataType}   = MMTests::Extract::DATA_MBITS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_Opname}     = "Tput";
	$self->{_FieldLength} = 12;
	$self->{_SingleType} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);

	open (INPUT, "$reportDir/noprofile/protocols");
	my $protocol = <INPUT>;
	chomp($protocol);
	close(INPUT);

	my @sizes;
	my @files = <$reportDir/noprofile/$protocol-*.1>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $size = $elements[-1];
		$size =~ s/\.1$//;
		push @sizes, $size;
	}
	@sizes = sort {$a <=> $b} @sizes;

	foreach my $size (@sizes) {
		my $file = "$reportDir/noprofile/$protocol-$size.log";
		my $confidenceLimit;
		my $throughput;
		my $iteration = 0;

		foreach $file (<$reportDir/noprofile/$protocol-$size.*>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my @elements = split(/\s+/, $_);
				if ($_ =~ /Confidence intervals: Throughput/) {
					my @subelements = split(/\s+/, $_);
					$confidenceLimit = $subelements[5];
					next;
				}
				if ($_ =~ /[a-zA-Z]/ || $_ =~ /^$/) {
					next;
				}
				my @elements = split(/\s+/, $_);
				if ($#elements > 3) {
					$throughput = $elements[-1];
				}
			}
			close(INPUT);
			push @{$self->{_ResultData}}, [ $size, ++$iteration, $throughput ];
		}
	}
	$self->{_Operations} = \@sizes;
}

1;
