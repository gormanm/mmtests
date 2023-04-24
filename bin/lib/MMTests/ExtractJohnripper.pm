# ExtractJohnripper.pm
package MMTests::ExtractJohnripper;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractJohnripper";
	$self->{_DataType}   = DataTypes::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "thread-errorlines";
	$self->{_ClientSubheading} = 1;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = $self->discover_scaling_parameters($reportDir, "johnripper-", "-1.log");

	# Extract per-client transaction information
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/johnripper-$client-*.log>;
		foreach my $file (@files) {
			my $benchmark;
			my $salt;

			$iteration++;
			my $input = $self->SUPER::open_log($file);
			while (!eof($input)) {
				my $line = <$input>;
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
					$self->addData("$client-$benchmark$salt", $iteration, $value);
				}
				
			}
			close($input);
		}
	}
}

1;
