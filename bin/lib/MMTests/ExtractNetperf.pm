# ExtractNetperf.pm
package MMTests::ExtractNetperf;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractNetperf";
	$self->{_PlotYaxis}  = DataTypes::LABEL_MBITS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

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

	foreach my $size (@sizes) {
		my $file = "$reportDir/$protocol-$size.log";
		my $iteration = 0;

		foreach $file (<$reportDir/$protocol-$size.*>) {
			my $send_tput = 0;
			my $recv_tput = 0;
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				$line =~ s/^\s+//;

				next if ($line =~ /Confidence intervals: Throughput/);
				next if ($line =~ /[a-zA-Z]/ || $line =~ /^$/);

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
			if ($protocol ne "UDP_STREAM") {
				$self->addData($size, ++$iteration, $send_tput);
			} else {
				$self->addData("send-$size", ++$iteration, $send_tput);
				$self->addData("recv-$size", ++$iteration, $recv_tput);
				if (($send_tput - $recv_tput) > ($send_tput / 10)) {
					$self->addData("loss-$size", ++$iteration, $send_tput - $recv_tput );
				}
			}
		}
	}
}

1;
