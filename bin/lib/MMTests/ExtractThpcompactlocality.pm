# ExtractThpcompactlocality.pm
package MMTests::ExtractThpcompactlocality;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractThpcompactlocality";
	$self->{_PlotYaxis}  = "Percentage";
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Percentage";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = $self->discover_scaling_parameters($reportDir, "threads-", ".log.gz");;

	foreach my $client (@clients) {
		my @local;
		my @remote;
		my @faults;
		my $uncertain = 0;

		my $input = $self->SUPER::open_log("$reportDir/threads-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /^fault/) {
				my $size;

				my @elements = split(/\s+/, $line);
				if ($elements[2] eq "base") {
					$size = 0;
				} else {
					$size = 1;
				}

				$faults[$size]++;
				if ($elements[5] == 1) {
					$local[$size]++;
				} elsif ($elements[5] == 0) {
					$remote[$size]++;
				} else {
					$uncertain++;
				}
			}
		}
		close $input;

		if ($faults[0] + $faults[1] != 0) {
			$self->addData("local-base-$client", 0, $faults[0]  == 0 ? 0 : $local[0] * 100 / $faults[0]);
			$self->addData("local-huge-$client", 0, $faults[1]  == 0 ? 0 : $local[1] * 100 / $faults[1]);
			$self->addData("remote-base-$client", 0, $faults[0] == 0 ? 0 : $remote[0] * 100 / $faults[0]);
			$self->addData("remote-huge-$client", 0, $faults[1] == 0 ? 0 : $remote[1] * 100 / $faults[1]);
			if ($uncertain != 0) {
				$self->addData("uncertain-$client", 0, $uncertain * 100 / ($faults[0] + $faults[1]));
			}
		} else {
			$self->addData("local-none-$client", 0, -1);
		}
	}
}

1;
