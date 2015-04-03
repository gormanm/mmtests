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

	my $loss;
	foreach my $size (@sizes) {
		my $file = "$reportDir/noprofile/$protocol-$size.log";
		my $confidenceLimit;
		my $iteration = 0;

		foreach $file (<$reportDir/noprofile/$protocol-$size.*>) {
			my $send_tput = 0;
			my $recv_tput = 0;
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
				if ($protocol ne "UDP_STREAM") {
					if ($#elements > 3) {
						$send_tput = $elements[-1];
					}
				} else {
					if ($#elements == 6) {
						$send_tput = $elements[-1];
					}
					if ($#elements == 4) {
						$recv_tput = $elements[-1];
					}
				}
			}
			close(INPUT);
			if ($protocol ne "UDP_STREAM") {
				push @{$self->{_ResultData}}, [ $size, ++$iteration, $send_tput ];
			} else {
				push @{$self->{_ResultData}}, [ "send-$size", ++$iteration, $send_tput ];
				push @{$self->{_ResultData}}, [ "recv-$size", ++$iteration, $recv_tput ];
				if (($send_tput - $recv_tput) > ($send_tput / 10)) {
					push @{$self->{_ResultData}}, [ "loss-$size", ++$iteration, $send_tput - $recv_tput ];
					$loss++;
				}
			}
		}
	}
	if ($protocol ne "UDP_STREAM") {
		$self->{_Operations} = \@sizes;
	} else {
		my @ops;
		my @directions = ("send", "recv");
		if ($loss) {
			push @directions, "loss";
		}
		foreach my $direction (@directions) {
			foreach my $size (@sizes) {
				push @ops, "$direction-$size";
			}
		}
		$self->{_Operations} = \@ops;
	}
}

1;
