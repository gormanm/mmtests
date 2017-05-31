# ExtractJohnripper.pm
package MMTests::ExtractJohnripper;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractJohnripper";
	$self->{_DataType}   = DataTypes::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_ClientSubheading} = 1;
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my @clients;
	my %benchmarks;

	my @files = <$reportDir/$profile/johnripper-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client transaction information
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/$profile/johnripper-$client-*.log>;
		foreach my $file (@files) {
			my $benchmark;
			my $salt;

			$iteration++;
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				my $value = -1;
				if ($line =~ /^Benchmarking: ([a-zA-Z0-9]+).*/) {
					$salt = "";
					$benchmark = $1;
					next;
				}
				if ($line =~ /^Many salts:\s+([0-9K]+) c/) {
					$salt = "-manysalt";
					$value = $1;
				}
				if ($line =~ /^Only one salt:\s+([0-9K]+) c/) {
					$salt = "-onesalt";
					$value = $1;
				}
				if ($line =~ /^Short:\s+([0-9K]+) c/) {
					$salt = "-short";
					$value = $1;
				}
				if ($line =~ /^Long:\s+([0-9K]+) c/) {
					$salt = "-long";
					$value = $1;
				}
				if ($line =~ /Raw:\s+([0-9K]+) c/) {
					$salt = "";
					$value = $1;
				}
				if ($value =~ /K/) {
					$value =~ s/K//;
					# $value *= 1000;
				}

				if ($value != -1) {
					$benchmarks{"$benchmark$salt"} = 1;
					push @{$self->{_ResultData}}, [ "$client-$benchmark$salt", $iteration, $value ];
				}
				
			}
			close(INPUT);
		}
	}

	my @ops;
	foreach my $client (@clients) {
		foreach my $benchmark (sort keys %benchmarks) {
			push @ops, "$client-$benchmark";
		}
	}
	$self->{_Operations} = \@ops;
}

1;
