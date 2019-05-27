# ExtractStressng.pm
package MMTests::ExtractStressng;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractStressng";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = $self->discover_scaling_parameters($reportDir, "stressng-", "-1.log");

	foreach my $client (@clients) {
		foreach my $file (<$reportDir/stressng-$client-*>) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $iteration = $split[-1];

			open(INPUT, $file) || die("Failed to open $file\n");
			my $reading = 0;
			while (!eof(INPUT)) {
				my $line = <INPUT>;

				if ($line =~ /\(secs\)/) {
					$reading = 1;
					next;
				}
				next if !$reading;

				$line =~ s/.*\] //;
				my @elements = split /\s+/, $line;

				my $testname = $elements[0];
				my $ops_sec = $elements[5];
				$self->addData("$testname-$client", $iteration, $ops_sec);
			}
			close(INPUT);
		}
	}
}

1;
