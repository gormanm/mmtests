# ExtractNetperf.pm
package MMTests::ExtractNetperf;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractNetperf";
	$self->{_DataType}   = DataTypes::DATA_MBITS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);

	open (INPUT, "$reportDir/$profile/protocols");
	my $protocol = <INPUT>;
	chomp($protocol);
	close(INPUT);

	my @sizes;
	my @files = <$reportDir/$profile/$protocol-*.1>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $size = $elements[-1];
		$size =~ s/\.1$//;
		push @sizes, $size;
	}
	@sizes = sort {$a <=> $b} @sizes;

	my $loss;
	foreach my $size (@sizes) {
		my $file = "$reportDir/$profile/$protocol-$size.log";
		my $confidenceLimit;
		my $iteration = 0;

		foreach $file (<$reportDir/$profile/$protocol-$size.*>) {
			my $send_tput = 0;
			my $recv_tput = 0;
			my $skip = 0;
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;

				my @elements = split(/\s+/, $line);
				if ($line =~ /Confidence intervals: Throughput/) {
					my @subelements = split(/\s+/, $line);
					$confidenceLimit = $subelements[5];
					next;
				}
				if ($line =~ /Desired confidence was not achieved/) {
					$skip = 1;
				}
				if ($line =~ /[a-zA-Z]/ || $line =~ /^$/) {
					next;
				}

				$line =~ s/^\s+//;
				my @elements = split(/\s+/, $line);
				if ($protocol ne "UDP_STREAM") {
					if ($#elements > 3) {
						$send_tput = $elements[-1];
					}
				} else {
					if ($#elements == 5) {
						$send_tput = $elements[-1];
					}
					if ($#elements == 3) {
						$recv_tput = $elements[-1];
					}
				}
			}
			close(INPUT);
#			if ($skip) {
#				next;
#			}
			if ($protocol ne "UDP_STREAM") {
				$self->addData($size, ++$iteration, $send_tput);
			} else {
				$self->addData("send-$size", ++$iteration, $send_tput);
				$self->addData("recv-$size", ++$iteration, $recv_tput);
				if ($loss || ($send_tput - $recv_tput) > ($send_tput / 10)) {
					$self->addData("loss-$size", ++$iteration, $send_tput - $recv_tput );
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
